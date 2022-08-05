package OpenILS::Application::Geo;

use strict;
use warnings;

use OpenSRF::AppSession;
use OpenILS::Application;
use base qw/OpenILS::Application/;
use List::MoreUtils qw(natatime);
use List::Util qw(min);

use OpenSRF::Utils::SettingsClient;
use OpenILS::Utils::CStoreEditor qw/:funcs/;
use OpenILS::Utils::Fieldmapper;
use OpenSRF::Utils::Cache;
use OpenILS::Application::AppUtils;
use Data::Dumper;
use JSON::XS;
my $U = "OpenILS::Application::AppUtils";

use OpenSRF::Utils::Logger qw/$logger/;

my $have_geocoder_free = eval {
    require Geo::Coder::Free;
    Geo::Coder::Free->import();
    1;
};
use Geo::Coder::OSM;
use Geo::Coder::Google;
use Geo::Coder::Bing;

use Math::Trig qw(great_circle_distance deg2rad);
use Digest::SHA qw(sha256_base64);

my $cache;
my $cache_timeout;

sub initialize {
    my $conf = OpenSRF::Utils::SettingsClient->new;

    $cache_timeout = $conf->config_value(
            "apps", "open-ils.geo", "app_settings", "cache_timeout" ) || 300;
}
sub child_init {
    $cache = OpenSRF::Utils::Cache->new('global');
}

sub calculate_driving_distance {
    my ($self, $conn, $auth, $pointA, $pointB) = @_;

    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $pointA;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $pointB;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Malformed coordinates") unless scalar(@{ $pointA }) == 2;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Malformed coordinates") unless scalar(@{ $pointB }) == 2;

    my $e = new_editor(xact => 1, authtoken=>$auth);
    return $e->die_event unless $e->checkauth;
    #   get the requestor's org unit
    my $org = $e->requestor->ws_ou;
    my $use_geo = $e->retrieve_config_global_flag('opac.use_geolocation');
    $use_geo = ($use_geo and $U->is_true($use_geo->enabled));
    return new OpenILS::Event("GEOCODING_NOT_ENABLED") unless ($U->is_true($use_geo));

    return new OpenILS::Event("BAD_PARAMS", "desc" => "No org ID supplied") unless $org;
    my $service_id = $U->ou_ancestor_setting_value($org, 'opac.geographic_location_service_for_address');
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service_id));

    my $service = $e->retrieve_config_geolocation_service($service_id);
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service));   

    my $geo_coder = _create_geocoder($service);
    if (!$geo_coder) {
        return OpenILS::Event->new('GEOCODING_LOCATION_NOT_FOUND');
    }
    
    if ($service->service_code eq 'Bing') {
        my $origin_coord = join(',',@{ $pointA });
        my $dest_coord = join(',',@{ $pointB });
        my $uri = URI->new("https://dev.virtualearth.net/REST/v1/Routes/DistanceMatrix?origins=$origin_coord&destinations=$dest_coord&distanceUnit=km&travelMode=driving&key=".$service->api_key);
        my $results = $geo_coder->_rest_request($uri)->{results};        
        return $results->[0]->{travelDistance};
    } else {
        $logger->info($service->service_code." can not get driving distance. Reverting to as-the-crow-flies.");
        # if geocoder can't do driving distance just get as-the-crow-flies
       return calculate_distance($self, $conn, $pointA, $pointB);
    }
    return 0;
}

__PACKAGE__->register_method(
    method   => "calculate_driving_distance",
    api_name => "open-ils.geo.calculate_driving_distance",
    signature => {
        params => [
            {type => 'string', desc => 'User\'s authorization token'},
            {type => 'array', desc => 'An array containing latitude and longitude for point A'},
            {type => 'array', desc => 'An array containing latitude and longitude for point B'}
        ],
        return => { desc => 'Driving distance between points A and B in kilometers'}
    }
);

sub calculate_distance {
    my ($self, $conn, $pointA, $pointB) = @_;

    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $pointA;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $pointB;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Malformed coordinates") unless scalar(@{ $pointA }) == 2;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Malformed coordinates") unless scalar(@{ $pointB }) == 2;

    sub NESW { deg2rad($_[1]), deg2rad(90 - $_[0]) } # longitude, latitude
    my @A = NESW( $pointA->[0], $pointA->[1] );
    my @B = NESW( $pointB->[0], $pointB->[1] );
    my $km = great_circle_distance(@A, @B, 6378);

    return $km;
}
__PACKAGE__->register_method(
    method   => "calculate_distance",
    api_name => "open-ils.geo.calculate_distance",
    signature => {
        params => [
            {type => 'array', desc => 'An array containing latitude and longitude for point A'},
            {type => 'array', desc => 'An array containing latitude and longitude for point B'}
        ],
        return => { desc => '"Great Circle (as the crow flies)" distance between points A and B in kilometers'}
    }
);

sub _post_request {
    my ($bing, $uri, $form, $json_coder) = @_;
    my $json = $json_coder->encode($form); 
    return unless $uri;
    $logger->info($uri);
    $logger->info($form);
    my $res = $bing->{response} = $bing->ua->post($uri,'Content-Length' => 3500,'Content-Type' => 'application/json',Content => $json);
    unless($res->is_success){
        $logger->error("API ERROR\n");
        return;
    }

    my @error = split /\n/, $res->decoded_content;
    foreach(@error){
        $logger->error($_);
    }
 
    # Change the content type of the response from 'application/json' so
    # HTTP::Message will decode the character encoding.
    $res->content_type('text/plain');
 
    my $content = $res->decoded_content;
    return unless $content;
    my $data= eval { $json_coder->decode($res->decoded_content) };
    return unless $data;
    my @results = @{ $data->{resourceSets}[0]{resources} || [] };
    return wantarray ? @results : $results[0];
}

sub calculate_bulk_driving_distance {
    my ($self, $conn, $auth, $origin_array, $destination_array) = @_;

    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $origin_array;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $destination_array;

    my $e = new_editor(xact => 1, authtoken=>$auth);
    return $e->die_event unless $e->checkauth;
    #   get the requestor's org unit
    my $org = $e->requestor->ws_ou;
    my $use_geo = $e->retrieve_config_global_flag('opac.use_geolocation');
    $use_geo = ($use_geo and $U->is_true($use_geo->enabled));
    return new OpenILS::Event("GEOCODING_NOT_ENABLED") unless ($U->is_true($use_geo));

    return new OpenILS::Event("BAD_PARAMS", "desc" => "No org ID supplied") unless $org;
    my $service_id = $U->ou_ancestor_setting_value($org, 'opac.geographic_location_service_for_address');
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service_id));

    my $service = $e->retrieve_config_geolocation_service($service_id);
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service));   

    my $geo_coder = _create_geocoder($service);
    if (!$geo_coder) {
        return OpenILS::Event->new('GEOCODING_LOCATION_NOT_FOUND');
    }
    
    my @results;
    
    if ($service->service_code eq 'Bing') {
        my @origins;
        my @destinations;
        my $uri = URI->new("https://dev.virtualearth.net/REST/v1/Routes/DistanceMatrix?key=".$service->api_key);
      
        # get the data into the right form for our request
        foreach(@{$origin_array}){
            my %ocoord; 
            $ocoord{'latitude'} = $_->[0];
            $ocoord{'longitude'} = $_->[1];
            push(@origins, \%ocoord);
        }        
        $logger->info(Dumper(\@origins));
        
        foreach(@{$destination_array}){
            my %dcoord; 
            $dcoord{'latitude'} = $_->[0];
            $dcoord{'longitude'} = $_->[1];
            push(@destinations, \%dcoord);
        }
        $logger->info(Dumper(\@destinations));
        
        # find out how many coords we can process per request.
        my $budget = int(2500 / scalar(@origins));
        $logger->debug("data being chunked into ".$budget.".\n");
        my $it = natatime $budget, @origins;
        my $real_index = 0;
        my $json_coder = JSON::XS->new->convert_blessed;  
        
        while (my @coords = $it->())
        {
            my %content = (
                origins => \@coords, 
                destinations => \@destinations, 
                travelMode => "driving",
                timeUnit => "minute", 
                distanceUnit => "km"
            );
            $logger->info("Hash for JSON: ".Dumper(\%content));             
            my $rest_req = _post_request($geo_coder,$uri,\%content,$json_coder);
            # print Dumper $rest_req;
            #calculate the distance matrix for this chunk of origins.
            $logger->info("results from post: ".Dumper($rest_req));
            my @distance_matrix = eval{$rest_req->{results}};
             if(@distance_matrix){
                for my $ref (@distance_matrix) {
                    for (@$ref){
                        my %dist;
                        $dist{origin} = $_->{originIndex} + $real_index;
                        $dist{destination} = $_->{destinationIndex};
                        $dist{distance} = $_->{travelDistance}; 
                        push(@results,\%dist);
                        }
                }
             
                $logger->info("Information from server: ".Dumper(\@results));
                $real_index += min($budget,scalar(@coords));
                print("setting index to ".$real_index."\n");
            }               
        }
        
        return \@results;
    } else {
        $logger->info($service->service_code." can not get driving distance. Reverting to as-the-crow-flies.");
        # if geocoder can't do driving distance just get as-the-crow-flies
        my $index = 0; 
        foreach(@{$origin_array}){
            my $pointA = $_;
            my $dindex = 0;
            foreach(@{$destination_array}){
                my $pointB = $_;
                my $d = calculate_distance($self, $conn, $pointA, $pointB);
                my %dist;
                $dist{origin} = $index;
                $dist{destination} = $dindex;
                $dist{distance} = $d; 
                push(@results,\%dist);
                $dindex++;
            }
            $index++;
        }

        return \@results;
    }
    return [];
}

__PACKAGE__->register_method(
    method   => "calculate_bulk_driving_distance",
    api_name => "open-ils.geo.calculate_bulk_driving_distance",
    signature => {
        params => [
            {type => 'string', desc => 'User\'s authorization token'},
            {type => 'array', desc => 'An array containing latitude and longitude origin points as an array.'},
            {type => 'array', desc => 'An array containing latitude and longitude destination points as an array.'}
        ],
        return => { desc => 'Driving distance between origin points and destinations in kilometers'}
    }
);

sub sort_orgs_by_distance_from_coordinate {
    my ($self, $conn, $pointA, $orgs) = @_;

    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing coordinates") unless $pointA;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Malformed coordinates") unless scalar(@{ $pointA }) == 2;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Missing org list") unless $orgs;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "Empty org list") unless scalar(@{ $orgs }) > 0;

    my $e = new_editor(xact => 1);

    my $fleshed_orgs = $e->search_actor_org_unit([
        {
            "id" => $orgs
        }, {
            "flesh" => 1,
            "flesh_fields" => {"aou" => ["billing_address"]}
        }
    ]) or return (undef, $e->die_event);

    my @orgs_with_coordinates = grep {
           defined $_->billing_address
        && defined $_->billing_address->latitude
        && defined $_->billing_address->longitude } @$fleshed_orgs;
    my @orgs_without_coordinates = grep {
           !defined $_->billing_address
        || !defined $_->billing_address->latitude
        || !defined $_->billing_address->longitude } @$fleshed_orgs;

    my @org_ids_with_distances = map {
            [ $_->id, calculate_distance($self, $conn, $pointA, [
                    $_->billing_address->latitude,
                    $_->billing_address->longitude
                ]) ]
        } @orgs_with_coordinates;

    my @sorted_orgs = sort { $a->[1] <=> $b->[1] } @org_ids_with_distances;
    push @sorted_orgs, map { [ $_->id, -1 ] } sort { $a->name cmp $b->name } @orgs_without_coordinates;
    my @sorted_org_ids = map { $_->[0] } @sorted_orgs;

    return $self->api_name =~ /include_distances/ ? \@sorted_orgs : \@sorted_org_ids;
}
__PACKAGE__->register_method(
    method   => "sort_orgs_by_distance_from_coordinate",
    api_name => "open-ils.geo.sort_orgs_by_distance_from_coordinate",
    signature => {
        params => [
            {type => 'array', desc => 'An array containing latitude and longitude for the reference point'},
            {type => 'array', desc => 'An array of Context Organizational Unit IDs'}
        ],
        return => { desc => 'An array of Context Organizational Unit IDs sorted by geographic proximity to the reference point (closest first).  Units without coordinates are appended to the end of the list in alphabetical order by name relative to each other.'}
    }
);
__PACKAGE__->register_method(
    method   => "sort_orgs_by_distance_from_coordinate",
    api_name => "open-ils.geo.sort_orgs_by_distance_from_coordinate.include_distances",
    signature => {
        params => [
            {type => 'array', desc => 'An array containing latitude and longitude for the reference point'},
            {type => 'array', desc => 'An array of Context Organizational Unit IDs'}
        ],
        return => { desc => 'An array of Context Organizational Unit IDs and distances (each pair itself an array) sorted by geographic proximity to the reference point (closest first).  Units without coordinates are appended to the end of the list in alphabetical order by name relative to each other and given a distance of -1.'}
    }
);

# creates a Geo::Coder object
sub _create_geocoder { 
    my $service = shift;
    my $service_id = $service->id;
    my $geo_coder;
    eval {
        if ($service->service_code eq 'Free') {
            if ($have_geocoder_free) {
                $logger->debug("Using Geo::Coder::Free (service id $service_id)");
                $geo_coder = Geo::Coder::Free->new();
            } else {
                $logger->error("geosort: Geo::Coder::Free not installed but referenced.");
            }
        } elsif ($service->service_code eq 'Google') {
            $logger->debug("Using Geo::Coder::Google (service id $service_id)");
            $geo_coder =  Geo::Coder::Google->new(key => $service->api_key);
        } elsif ($service->service_code eq 'Bing') {
            $logger->debug("Using Geo::Coder::Bing (service id $service_id)");
            $geo_coder =  Geo::Coder::Bing->new(key => $service->api_key);
        } else {
            $logger->debug("Using Geo::Coder::OSM (service id $service_id)");
            $geo_coder =  Geo::Coder::OSM->new();
        }
    };
    if ($@ || !$geo_coder) {
        $logger->error("geosort: problem creating Geo::Coder instance : $@");
    }
    return $geo_coder;
}

sub retrieve_coordinates { # invoke 3rd party API for latitude/longitude lookup
    my ($self, $conn, $org, $address) = @_;

    my $e = new_editor(xact => 1);
    # TODO: if we're not going to require authentication, we may want to consider
    #       implementing some options for limiting outgoing geo-coding API calls
    # return $e->die_event unless $e->checkauth;

    $org = ref($org) ? $org->id : $org; # never trust the caller :-)

    my $use_geo = $e->retrieve_config_global_flag('opac.use_geolocation');
    $use_geo = ($use_geo and $U->is_true($use_geo->enabled));
    return new OpenILS::Event("GEOCODING_NOT_ENABLED") unless ($U->is_true($use_geo));

    return new OpenILS::Event("BAD_PARAMS", "desc" => "No org ID supplied") unless $org;
    my $service_id = $U->ou_ancestor_setting_value($org, 'opac.geographic_location_service_for_address');
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service_id));

    my $service = $e->retrieve_config_geolocation_service($service_id);
    return new OpenILS::Event("GEOCODING_NOT_ALLOWED") unless ($U->is_true($service));

    $address =~ s/^\s+//;
    $address =~ s/\s+$//;
    return new OpenILS::Event("BAD_PARAMS", "desc" => "No address supplied") unless $address;

    # Return cached coordinates if available. We're assuming that any
    # geolocation service will give roughly equivalent results, so we're
    # using a hash of the user-supplied address as the cache key, not
    # address + OU.
    my $cache_key = 'geo.address.' . sha256_base64($address);
    my $coords = OpenSRF::Utils::JSON->JSON2perl($cache->get_cache($cache_key));
    return $coords if $coords;

    my $geo_coder = _create_geocoder($service);
    if (!$geo_coder) {
        return OpenILS::Event->new('GEOCODING_LOCATION_NOT_FOUND');
    }
    my $location;
    eval {
        $location = $geo_coder->geocode(location => $address);
    };
    if ($@) {
        $logger->error("geosort: problem invoking location lookup : $@");
        return OpenILS::Event->new('GEOCODING_LOCATION_NOT_FOUND');
    }

    my $latitude; my $longitude;
    return new OpenILS::Event("GEOCODING_LOCATION_NOT_FOUND") unless ($U->is_true($location));
    if ($service->service_code eq 'Free') {
       $latitude = $location->{'latitude'};
       $longitude = $location->{'longitude'};
    } elsif ($service->service_code eq 'Google') {
       $latitude = $location->{'geometry'}->{'location'}->{'lat'};
       $longitude = $location->{'geometry'}->{'location'}->{'lng'};
    } elsif ($service->service_code eq 'Bing') {
       $latitude = $location->{point}{coordinates}[0];
       $longitude = $location->{point}{coordinates}[1];
    } else {
       $latitude = $location->{lat};
       $longitude = $location->{lon};
    }
    $coords = { latitude => $latitude, longitude => $longitude };
    $cache->put_cache($cache_key, OpenSRF::Utils::JSON->perl2JSON($coords), $cache_timeout);

    return $coords;
}
__PACKAGE__->register_method(
    method   => "retrieve_coordinates",
    api_name => "open-ils.geo.retrieve_coordinates",
    signature => {
        params => [
            {type => 'number', desc => 'Context Organizational Unit'},
            {type => 'string', desc => 'Address to look-up as a text string'}
        ],
        return => { desc => 'Hash/object containing latitude and longitude for the provided address.'}
    }
);

1;
