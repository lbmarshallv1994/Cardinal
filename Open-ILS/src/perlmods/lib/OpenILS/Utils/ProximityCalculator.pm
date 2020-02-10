package OpenILS::Utils::ProximityCalculator;
use strict; use warnings;
use Geo::Coder::Bing;
use JSON;
use Data::Dumper;
use URI;
use OpenSRF::System;
use OpenILS::Application::Actor;
use OpenSRF::AppSession;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Application::AppUtils;
use OpenILS::Utils::CStoreEditor qw/:funcs/;

our $U = "OpenILS::Application::AppUtils";
my $actor;

sub new {
    my ($class, $api_key) = @_;
    my $self = {
        editor => new_editor(),
        bing => Geo::Coder::Bing->new(key => $api_key),
        hub_cache => {},
        coord_cache => {},
        
    };
    $self->{editor}->init;
    return bless($self, $class);
}

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

# Use Bing maps API to calculate the distances between all shipping hubs
sub calculate_distance_matrix {
    my $self = shift;
    # find hubs for all OUs
    my @hubs = $self->get_all_hubs();
    my %hub_coord;
    # find addresses of all hub OUs
    my %hub_addr = $self->get_addr_from_ou(uniq(@hubs));
    while( my($k,$v) = each %hub_addr){
        # use Bing to find the longitude and latitude of all hub OUs
        $hub_coord{$k} = $self->get_coord_from_address($v);
    }
    my @origins = values(%hub_coord);
    my @destinations = values(%hub_coord);
    my @hub_ids = keys(%hub_coord);
    # make one giant request to bing to calculate our distance matrix
    my @distance_matrix = $self->proximity_between_coords(\@origins,\@destinations);
    $self->{editor}->xact_begin;
    for my $ref (@distance_matrix) {
        for (@$ref){
            # create our AOUSHD objects for the data returned
            my $dist = Fieldmapper::actor::org_unit_shipping_hub_distance->new;
            $dist->orig_hub($hub_ids[$_->{originIndex}]);
            $dist->dest_hub($hub_ids[$_->{destinationIndex}]);
            $dist->distance($_->{travelDistance});
            # place AOUSHD into the DB
            $self->{editor}->runmethod('create', 'actor.org_unit_shipping_hub_distance', 'aoushd', $dist);
        }
    }
    # commit to DB 
    $self->{editor}->xact_commit;
}

sub hub_matrix {
    my ($self, $origin_hub, @dest_hubs) = @_;
    my @d = $self->{editor}->json_query({
        select => {'aoushd' => [{column => 'dest_hub'},{column => 'distance'}]},
        from => 'aoushd',
        where => {'orig_hub'=>[$origin_hub],'dest_hub'=>@dest_hubs},
        order_by => [
            {class => 'aoushd', field => 'distance', direction => 'ASC'},
        ]
    });
    
    my %matrix;
    for my $ref (@d) {
        for (@$ref){
            $matrix{$_->{'dest_hub'}}=$_->{distance};
        }
    }
    return %matrix; 
}

sub get_addr_from_ou {
my($self,@org_ids) = @_;
    my @ma = $self->{editor}->json_query({
        select => {
            aou => [
                {
                    column => 'id',
                }            
            ],
            aoa => [
                {
                    column => 'city',
                },{
                    column => 'state',
                },{
                    column => 'county',
                },{
                    column => 'street1',
                },{
                    column => 'street2',
                },{
                    column => 'post_code',
                }             
            ]
        },
        from => {aou => {'aoa'}},
        where => {id=>[@org_ids]}
    });
    my %addrs;
    for my $ref (@ma) {
        for (@$ref){
            unless($_->{street2}){
                $addrs{$_->{id}} = $_->{street1}.", ".$_->{city}.", ".$_->{county}.", ".$_->{state}.", ".$_->{post_code};
            }
            else{
                $addrs{$_->{id}} = $_->{street1}." ".$_->{street2}.", ".$_->{city}.", ".$_->{county}.", ".$_->{state}.", ".$_->{post_code};
            }
        }
    }
    return %addrs; 
}

sub get_hub_from_ou {
my($self,@org_ids) = @_;
my @sh = $self->{editor}->json_query({
        select => {
            aou => ['id'],
            "h1" => [{column=>'hub',alias=>'my_hub'}],
            "h2" => [{column=>'hub',alias=>'parent_hub'}]
        },
        from => {aou=>{h1=>{class=>'aoush',fkey => 'id',field => 'org_unit',type=>'left'},h2=>{class=>'aoush',fkey => 'parent_ou',field => 'org_unit',type=>'left'}}},
        where => {"+aou"=>{id=>[@org_ids]}}
    });
    return $sh[0][0]->{'my_hub'} || $sh[0][0]->{'parent_hub'};
}

sub get_all_hubs {
my($self) = @_;
my @sh = $self->{editor}->json_query({
        select => {
            aoush => ['hub'],
        },
        from => 'aoush'
    });
    my @hubs;
    for my $ref (@sh) {
        for (@$ref){
        push @hubs, $_->{hub}
        }
    }
    return @hubs; 
}


# get longitude and lattitude from an OU
sub get_coord_from_ou{
    my( $self, $org_id ) = @_;
    my $org1addr = $self->get_addr_from_ou($org_id)->[0];
    my $org1geo = $self->{bing}->geocode(location => $org1addr);
    my $coords = $org1geo->{point}{coordinates}[0].",".$org1geo->{point}{coordinates}[1];
    $self->{coord_cache}->{$org_id} = $coords;
    return $coords;
}

sub get_coord_from_address{
    my( $self, $addr ) = @_;
    my $org1geo = $self->{bing}->geocode(location => $addr);
    return $org1geo->{point}{coordinates}[0].",".$org1geo->{point}{coordinates}[1];
}

sub proximity_between_coord{
my( $self, $origin_coord, $dest_coord ) = @_;
    my $b = $self->{bing};
    return _prox_request($origin_coord,$dest_coord)->[0]->{travelDistance};
}

sub _prox_request{
my( $self, $origin_coord, $dest_coord ) = @_;
    my $b = $self->{bing};
    unless( $b->{key} ){
    print("API Key was not found")
    }
    my $uri = URI->new("https://dev.virtualearth.net/REST/v1/Routes/DistanceMatrix?origins=$origin_coord&destinations=$dest_coord&distanceUnit=mi&travelMode=driving&key=".$b->{key});
    return $b->_rest_request($uri)->{results}
}

sub proximity_between_coords{
my( $self, $origin_ref, $dest_ref ) = @_;
    my @origins = @{ $origin_ref };
    my @destinations = @{ $dest_ref };
    return $self->_prox_request(join(';',@origins),join(';',@destinations));
}


sub proximity_between_ou {
       my( $self, $org1, $org2 ) = @_; 
       my @addrs = $self->get_addr_from_ou($org1,$org2);
       print("Calculating route between ".$addrs[0]." and ".$addrs[1]);
       return $self->proximity_between_coord($self->get_coord_from_address($addrs[0]),$self->get_coord_from_address($addrs[1]));
}

sub proximity_between_hub {
 my( $self, $org1, $org2 ) = @_; 
 my %hubs = $self->get_hub_from_ou($org1,$org2);
 if($hubs{$org1} == 0 || $hubs{$org2} == 0){
 print("Requested OU does not have a shipping hub!");
 die;
 }

 return $self->proximity_between_ou($hubs{$org1},$hubs{$org2});
}

sub get_target_hubs{
    my $self = shift;
    my @target_copies = shift;
    my @h = $self->{editor}->json_query({
        select => {'acp' => ['id'],
            "h1" => [{column=>'hub',alias=>'my_hub'}],
            "h2" => [{column=>'hub',alias=>'parent_hub'}]},
        from => {'acp' =>{aou => {fkey => 'circ_lib',field => 'id', join => {
        h1=>{class=>'aoush',fkey => 'id',field => 'org_unit',type=>'left'},h2=>{class=>'aoush',fkey => 'parent_ou',field => 'org_unit',type=>'left'}
        }}}},
        where => {'+acp'=>{id => @target_copies}}
    }); 
        my %hubs;
    for my $ref (@h) {
        for (@$ref){
        $hubs{$_->{id}} = $_->{'my_hub'} || $_->{'parent_hub'};
        }
    }
    return %hubs; 
}


=begin work zone
OpenSRF::System->bootstrap_client(config_file =>'/openils/conf/opensrf_core.xml');
my $pc = OpenILS::Utils::ProximityCalculator->new("AosM-K7Hdbk-OMZ1jcJC1boNDGRpoYRL_bzgK6pqKNNVAc2-z0qbOVtc3itjfWj5");
=cut
1;