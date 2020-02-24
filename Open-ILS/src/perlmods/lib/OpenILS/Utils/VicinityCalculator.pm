package OpenILS::Utils::VicinityCalculator;
use strict; use warnings;
use Geo::Coder::Bing;
use JSON;
use Data::Dumper;
use URI;
use OpenSRF::System;
use OpenILS::Application::Actor;
use OpenSRF::Utils::Logger qw(:logger);
use OpenSRF::AppSession;
use OpenILS::Utils::Fieldmapper;
use OpenSRF::Utils::SettingsClient;
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
    my @distance_matrix = $self->vicinity_between_coords(\@origins,\@destinations);
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
        select => [{column=>'org_unit'},{column=>'hub'}],
        from => [
            'actor.list_org_unit_ancestor_shipping_hub',@org_ids]
    });
    return $sh[0][0]->{'hub'};
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

sub vicinity_between_coord{
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

sub vicinity_between_coords{
my( $self, $origin_ref, $dest_ref ) = @_;
    my @origins = @{ $origin_ref };
    my @destinations = @{ $dest_ref };
    return $self->_prox_request(join(';',@origins),join(';',@destinations));
}


sub vicinity_between_ou {
       my( $self, $org1, $org2 ) = @_; 
       my @addrs = $self->get_addr_from_ou($org1,$org2);
       print("Calculating route between ".$addrs[0]." and ".$addrs[1]);
       return $self->vicinity_between_coord($self->get_coord_from_address($addrs[0]),$self->get_coord_from_address($addrs[1]));
}

sub vicinity_between_hub {
 my( $self, $org1, $org2 ) = @_; 
 my %hubs = $self->get_hub_from_ou($org1,$org2);
 if($hubs{$org1} == 0 || $hubs{$org2} == 0){
 print("Requested OU does not have a shipping hub!");
 die;
 }

 return $self->vicinity_between_ou($hubs{$org1},$hubs{$org2});
}

sub get_target_hubs{
    my $self = shift;
    my $copies_ref = shift;
    my @target_copies = @{ $copies_ref };
    my @h = $self->{editor}->json_query({
        select => {'acp' => ['id','circ_lib']},
        from => 'acp',
        where => {'+acp'=>{id => [@target_copies]}}
    }); 
        my %circ_libs;
    for my $ref (@h) {
        for (@$ref){
        $circ_libs{$_->{id}} = $_->{circ_lib};
        }
    }

    my %circ_hubs;
    my %hubs;
    my @sh = $self->{editor}->json_query({
        select => [{column=>'org_unit'},{column=>'hub'}],
        from => [
            'actor.list_org_unit_ancestor_shipping_hub',values(%circ_libs)]
    });
        for my $ref (@sh) {
        for (@$ref){
        $circ_hubs{$_->{org_unit}} = $_->{hub};
        }
    }
    foreach my $copy(@target_copies){
    $hubs{$copy} = $circ_hubs{$circ_libs{$copy}};
    }
   
    return %hubs; 
}
=begin work zone
OpenSRF::System->bootstrap_client(config_file =>'/openils/conf/opensrf_core.xml');
    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);
my $pc = OpenILS::Utils::VicinityCalculator->new("AosM-K7Hdbk-OMZ1jcJC1boNDGRpoYRL_bzgK6pqKNNVAc2-z0qbOVtc3itjfWj5");
my @copy_id = (4007,3507,3807,3307,3707,3207,3607,3107, 4819);

OpenSRF::System->bootstrap_client(config_file =>'/openils/conf/opensrf_core.xml');
    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);
my $pc = OpenILS::Utils::VicinityCalculator->new("AosM-K7Hdbk-OMZ1jcJC1boNDGRpoYRL_bzgK6pqKNNVAc2-z0qbOVtc3itjfWj5");
#my $pc = OpenILS::Utils::VicinityCalculator->new();
#$pc->calculate_distance_matrix();
#my @dest_hubs = (226,182,393,4,208);
#my @matrix = $pc->hub_matrix(180,\@dest_hubs);
#my @targets = (17024825,14189348,5952821,17056866,15214541,14074994 );
#my %hubs = $pc->get_target_hubs(\@targets);
#print(Dumper(\%hubs));
print($pc->get_hub_from_ou(2));


OpenSRF::System->bootstrap_client(config_file =>'/openils/conf/opensrf_core.xml');
    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);
my $pc = OpenILS::Utils::VicinityCalculator->new("AosM-K7Hdbk-OMZ1jcJC1boNDGRpoYRL_bzgK6pqKNNVAc2-z0qbOVtc3itjfWj5");
#my $prox = $pc->vicinity_between_hub(102,109);
#print "\n\nDistance is $prox miles\n";
#my @origins = ("35.778774,-78.685422", "36.280466,-76.214402");
#my @destinations = ("34.694165,-76.551269", "35.595012,-82.551707");
#print Dumper($pc->vicinity_between_coords(\@origins,\@destinations));
# all this stuff below is gonna be a function that dumps the distance matrix into the database, it'll be run for every hub and we'll probably only need to run it once a year. Each iteration of the function will produce less data since the x runs before it would have calculated data we can use again.
my $hold_id = 6832841;
my $request_ou = $pc->ou_from_hold($hold_id);
my %proxmap = $pc->compile_weighted_vicinity_map($hold_id);
print("\n$request_ou\n");
my @OU;

push @OU, $request_ou;
while( my($k,$v) = each %proxmap){
    push @OU, $v->{ou};
}
my %hubs = $pc->get_hub_from_ou(@OU);

#my %hub_addr = $pc->get_addr_from_ou(uniq(values(%hubs)));

# save coords so I don't blow through my queries on bing
my %hub_coord = ('260' => '36.4941,-79.73601','102' => '35.240596,-81.342891','314' => '35.511453,-78.3456','182' => '36.404213,-79.333114','325' => '34.775483,-79.465872','310' => '35.9207,-81.17589','4' => '35.293008,-81.555723','161' => '35.426298,-83.444665','189' => '35.92217133,-81.523353','142' => '36.109843,-78.296138','208' => '35.055522,-78.881343','237' => '35.304749,-76.789123','112' => '35.596714,-82.554788','370' => '36.32762667,-78.40572167','180' => '35.59727,-77.58532333','343' => '36.309471,-78.587604','269' => '35.40015517,-78.814922','177' => '35.487138,-82.9919','277' => '36.244018,-80.854557','291' => '35.266071,-77.581526','298' => '35.315485,-82.462982','196' => '35.68377417,-82.0106725','107' => '35.81924333,-80.25970833','367' => '35.240179,-82.216521','187' => '35.195678,-78.068236','166' => '35.897794,-80.559671','306' => '35.787559,-80.887852','226' => '36.098649,-80.252405','137' => '36.15954,-81.14848','238' => '35.543145,-77.05459333');
# get coords for each hub
#while( my($k,$v) = each %hub_addr){
#    $hub_coord{$k} = $pc->get_coord_from_address($v);
#}



# get distance matrix between my hub and every other hub
my $origin_hub = $hubs{$request_ou};
my @origins = ($hub_coord{$origin_hub});
my @destinations = values(%hub_coord);
my @hub_ids = keys(%hub_coord);
my @distance_matrix = $pc->vicinity_between_coords(\@origins,\@destinations);
my %hub_distance_matrix;

# break down distance matrix into hash
    $pc->{editor}->xact_begin;
    for my $ref (@distance_matrix) {
        for (@$ref){
        $hub_distance_matrix{$hub_ids[$_->{destinationIndex}]} = $_->{travelDistance};
        # put them in the database from here
        my $dist = Fieldmapper::actor::org_unit_shipping_hub_distance->new;
        $dist->orig_hub($origin_hub);
        $dist->dest_hub($hub_ids[$_->{destinationIndex}]);
        $dist->distance($_->{travelDistance});
        $pc->{editor}->runmethod('create', 'actor.org_unit_shipping_hub_distance', 'aoushd', $dist);
        }
    }
    $pc->{editor}->xact_commit;
print Dumper(\%hub_distance_matrix);
=cut
1;