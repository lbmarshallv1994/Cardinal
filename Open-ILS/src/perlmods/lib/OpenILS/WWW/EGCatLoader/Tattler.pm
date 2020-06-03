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
    my $usr = $ctx->{user};
    # only staff can update the list
    $logger->info("TATTLER");
    $logger->info($usr);
    $logger->info("profile: ".$usr->profile);
    $logger->info("staff: ".$ctx->{is_staff});
    $logger->info("permission: ".$self->{editor}->allowed('UPDATE_RECORD'));
    return Apache2::Const::FORBIDDEN unless $usr;
    if( $cgi->request_method eq 'POST'){
        $self->{editor}->xact_begin;
        my $sysID = $cgi->param('systemID');
        my $report = $cgi->param('reportName');
        my @copy_array = $cgi->param("copyID[]");
        foreach(@copy_array){
            my $rec = Fieldmapper::config::tattler_ignore_list->new;
            $logger->info("Adding Copy ".$_." to tattler ignore list for ".$report." at system ".$sysID);
            $rec->org_unit($sysID);
            $rec->target_copy($_);
            $rec->report_name($report);
            $self->{editor}->create_config_tattler_ignore_list($rec);
        }
        $self->{editor}->xact_commit;
    }
    return Apache2::Const::OK;
}

1;