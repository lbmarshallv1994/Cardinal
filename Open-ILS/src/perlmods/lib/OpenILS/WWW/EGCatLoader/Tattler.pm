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
    $logger->info("!!TATTLER!!");
    $logger->info($cgi->param('reportName'));
    $logger->info(Dumper($cgi->param));
    
    my $sysID = $cgi->param('systemID');
    my $report = $cgi->param('reportName');

    my $copy_array_ref = $cgi->param('copyID[]');
    foreach(@$copy_array_ref){
        my $rec = Fieldmapper::config::tattler_ignore_list->new;
        $rec->org_unit($sysID);
        $rec->target_copy($_);
        $rec->report_name($report);
        $self->{editor}->create_config_tattler_ignore_list($rec);
    }
    $self->{editor}->xact_commit;
}

1;