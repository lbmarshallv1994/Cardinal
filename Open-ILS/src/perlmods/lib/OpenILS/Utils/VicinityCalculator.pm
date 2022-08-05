package OpenILS::Utils::VicinityCalculator;
use strict; use warnings;
use Geo::Coder::Bing;
use JSON;
use Data::Dumper;
use URI;
use OpenSRF::System;
use OpenILS::Application::Actor;
use OpenSRF::Utils::Logger qw($logger);
use OpenSRF::AppSession;
use OpenILS::Utils::Fieldmapper;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Application::AppUtils;
use OpenILS::Utils::CStoreEditor qw/:funcs/;

our $U = "OpenILS::Application::AppUtils";
my $actor;

sub new {
    my ($class, $auth) = @_;
    my $self = {
        editor => new_editor(authtoken => $auth),
        auth => $auth,
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
    # find addresses of all hub OUs
    $logger->info("Getting shipping hub addresses");
    my %hub_coord = $self->get_coord_from_ou(uniq(@hubs));
    my @origins = values(%hub_coord);
    my @destinations = values(%hub_coord);
    my @hub_ids = keys(%hub_coord);
    # make one giant request to our geolocation service to calculate our distance matrix
    my $geo = OpenSRF::AppSession->create('open-ils.geo');
    my $geo_request = $geo->request('open-ils.geo.calculate_bulk_driving_distance',
            $self->{auth}, \@origins, \@destinations);
    my @distance_matrix = @{$geo_request};
    if(@distance_matrix){
        $self->{editor}->xact_begin;
        # clear out existing matrix
        $self->clear_hub_distances();
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
    else{
    $logger->error("API failed to calculate distance matrix");
    }
}

# remove all existing distance calculations.
# TODO make this all happen in one query
# what could the analog to DELETE FROM TABLE be?
sub clear_hub_distances {
my($self,@org_ids) = @_;
    my @ma = $self->{editor}->json_query({
        select => {
            aoushd => [
                {
                    column => 'id',
                }            
            ]
        },
        from => 'aoushd'
    });

    for my $ref (@ma) {
        for (@$ref){
            my $dist = Fieldmapper::actor::org_unit_shipping_hub_distance->new;
            $dist->id($_->{id});
            $self->{editor}->runmethod('delete', 'actor.org_unit_shipping_hub_distance', 'aoushd', $dist);
        }
    }
}

sub get_all_hubs {
my($self) = @_;
my @sh = $self->{editor}->json_query({
        select => {
            aou => ['shipping_hub_ou'],
        },
        from => 'aou'
    });
    my @hubs;
    for my $ref (@sh) {
        for (@$ref){
        my $hub = $_->{shipping_hub_ou};
        if($hub && $hub != 0 && !($hub eq '')){ 
            push @hubs, $hub;
        }
        }
    }
    return @hubs; 
}

package OpenILS::Utils::VicinityCalculator::Matrix;
use OpenSRF::System;
use OpenILS::Application::Actor;
use OpenSRF::Utils::Logger qw(:logger);
use OpenSRF::AppSession;
use OpenILS::Utils::Fieldmapper;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Application::AppUtils;
use OpenILS::Utils::CStoreEditor qw/:funcs/;
use Data::Dumper;

our $U = "OpenILS::Application::AppUtils";
sub new {
    my ($class) = @_;
    my $self = { editor => new_editor() };
    $self->{editor}->init;
    return bless($self, $class);
}

sub hub_matrix {
    my ($self, $origin_hub, $dest_hubs_ref) = @_;
    my @dest_hubs = @{$dest_hubs_ref};
    my @d = $self->{editor}->json_query({
        select => {'aoushd' => [{column => 'dest_hub'},{column => 'distance'}]},
        from => 'aoushd',
        where => {'orig_hub'=>[$origin_hub],'dest_hub'=>[@dest_hubs]},
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
    # hub matrix will be undefined if any destination hubs are missing from the return list.
    for my $hub (@dest_hubs){
        next if $matrix{$hub};
        $logger->error("OU $origin_hub has no calculation to OU $hub. open-ils.vicinity-calculator.build-distance-matrix must be run before vicinity based hold targeting can continue!");
        return undef;
    }
    return %matrix; 
}

sub distance_between_hubs {
    my ($self, $origin_hub, $dest_hub) = @_;
    my @d = $self->{editor}->json_query({
        select => {'aoushd' => [{column => 'distance'}]},
        from => 'aoushd',
        where => {'orig_hub'=>[$origin_hub],'dest_hub'=>[$dest_hub]}
    });
    for my $ref (@d) {
        for (@$ref){
            return $_->{distance};
        }
    }
    $logger->error("OU $origin_hub has no calculation to OU $dest_hub. open-ils.vicinity-calculator.build-distance-matrix must be run!");
    return undef;
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

sub get_hub_from_ou {
my($self,@org_ids) = @_;
my @sh = $self->{editor}->json_query({
        select => [{column=>'org_unit'},{column=>'hub'}],
        from => [
            'actor.list_org_unit_ancestor_shipping_hub',@org_ids]
    });
    return $sh[0][0]->{'hub'};
}
1;