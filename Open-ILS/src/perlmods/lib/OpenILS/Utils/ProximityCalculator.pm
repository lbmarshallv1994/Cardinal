package OpenILS::Utils::ProximityCalculator;
use strict; use warnings;
use WWW::REST;
use OpenILS::Application::Actor;
use OpenSRF::AppSession;
my $actor = OpenSRF::AppSession->create('open-ils.actor');

sub get_ou {
    my $org = shift || '-';
    my $org_unit;

    if ($org eq '-') {
         $org_unit = $actor->request(
            'open-ils.actor.org_unit_list.search' => parent_ou => undef
        )->gather(1);
    } elsif ($org !~ /^\d+$/o) {
         $org_unit = $actor->request(
            'open-ils.actor.org_unit_list.search' => shortname => uc($org)
        )->gather(1);
    } else {
         $org_unit = $actor->request(
            'open-ils.actor.org_unit_list.search' => id => $org
        )->gather(1);
    }

    return $org_unit;
}

sub proximity {
    my( $self, $org1id, $org2id ) = @_;
    my $org1 = get_ou($org1id)->[0];
    my $org2 = get_ou($org2id)->[0];
    my $org1addr = OpenILS::Application::Actor::retrieve_org_address($org1->mailing_address);
    my $org2addr = OpenILS::Application::Actor::retrieve_org_address($org2->mailing_address);
    print($org1 . ' ' . $org2);
    print($org1addr . '   ' . $org2addr);
}

1;