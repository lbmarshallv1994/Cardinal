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
        bing => Geo::Coder::Bing->new(key => $api_key)
    };
    return bless($self, $class);
}

sub get_addr_from_ou {
my($self,@org_ids) = @_;
    my @ma = $self->{editor}->json_query({
        select => {
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
        from => 'aoa',
        where => {org_unit => [@org_ids]}
    });
    my @addrs;
    for my $ref (@ma) {
        for (@$ref){
            unless($_->{street2}){
                push @addrs, $_->{street1}.", ".$_->{city}.", ".$_->{county}.", ".$_->{state}.", ".$_->{post_code};
            }
            else{
                push @addrs, $_->{street1}." ".$_->{street2}.", ".$_->{city}.", ".$_->{county}.", ".$_->{state}.", ".$_->{post_code};
            }
        }
    }
    return @addrs; 
}

# get longitude and lattitude from an OU
sub get_coord_from_ou{
    my( $self, $org_id ) = @_;
    my $org1addr = $self->get_addr_from_ou($org_id)->[0];
    my $org1geo = $self->{bing}->geocode(location => $org1addr);
    return $org1geo->{point}{coordinates}[0].",".$org1geo->{point}{coordinates}[1];
}

sub get_coord_from_address{
    my( $self, $addr ) = @_;
    my $org1geo = $self->{bing}->geocode(location => $addr);
    return $org1geo->{point}{coordinates}[0].",".$org1geo->{point}{coordinates}[1];
}

sub proximity_between_coord{
my( $self, $origin_coord, $dest_coord ) = @_;
    my $b = $self->{bing};
    my $uri = URI->new("https://dev.virtualearth.net/REST/v1/Routes/DistanceMatrix?origins=$origin_coord&destinations=$dest_coord&travelMode=driving&key=".$b->{key});
    return $b->_rest_request($uri)->{results}->[0]->{travelDistance};
}

sub proximity_between_ou {
       my( $self, $org1, $org2 ) = @_; 
       my @addrs = $self->get_addr_from_ou($org1,$org2);
       print("Calculating route between ".$addrs[0]." and ".$addrs[1]);
       return $self->proximity_between_coord($self->get_coord_from_address($addrs[0]),$self->get_coord_from_address($addrs[1]));
}

OpenSRF::System->bootstrap_client(config_file =>'/openils/conf/opensrf_core.xml');
my $pc = OpenILS::Utils::ProximityCalculator->new("AosM-K7Hdbk-OMZ1jcJC1boNDGRpoYRL_bzgK6pqKNNVAc2-z0qbOVtc3itjfWj5");
my $prox = $pc->proximity_between_ou(102,109);
print "\n\nDistance is $prox km\n";
1;