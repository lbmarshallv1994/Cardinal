package OpenILS::WWW::EGCatLoader;
use strict; use warnings;
use Apache2::Const -compile => qw(OK DECLINED FORBIDDEN HTTP_INTERNAL_SERVER_ERROR REDIRECT HTTP_BAD_REQUEST);
use OpenSRF::Utils::JSON;
use OpenSRF::Utils::Logger qw/$logger/;
use OpenILS::Utils::CStoreEditor qw/:funcs/;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Application::AppUtils;
my $U = 'OpenILS::Application::AppUtils';

sub update_tattle_list {
    my $self = shift;
    my %kwargs = @_;
    my $ctx = $self->ctx;
    my $cgi = $self->cgi;
    return Apache2::Const::HTTP_BAD_REQUEST unless $cgi->request_method eq 'POST';
    $self->{editor}->xact_begin;
    my $sysID = $cgi->param('systemID');
    my $report = $cgi->param('reportName');
    $cgi->param('copyID');
    foreach($cgi->param('copyID')){
        my $dist = Fieldmapper::config::tattler_ignore_list->new;
        $dist->org_unit($sysID);
        $dist->target_copy($_);
        $dist->report_name($report);
        $self->{editor}->create_config_tattler_ignore_list($dist);
    }
    $self->{editor}->xact_commit;
}

1;