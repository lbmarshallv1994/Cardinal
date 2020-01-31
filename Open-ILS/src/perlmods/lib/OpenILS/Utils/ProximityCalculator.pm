package OpenILS::Utils::ProximityCalculator;
use strict; use warnings;
use WWW::REST;
use OpenILS::Application::Actor;

sub proximity {
    my $org1 = shift;
    my $org2 = shift;
    my $org1addr = OpenILS::Application::Actor::retrieve_org_address($org1);
    my $org2addr = OpenILS::Application::Actor::retrieve_org_address($org2);
    print($org1addr . '   ' . $org2addr);
}

1;