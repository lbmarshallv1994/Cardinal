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

    my $dist = Fieldmapper::config::tattler_ignore_list->new;
    $dist->org_unit(1);
    $dist->target_copy(2);
    $dist->report_name("test");
    $self->{editor}->runmethod('create', 'config.tattler_ignore_list', 'igl', $dist);
    return Apache2::Const::HTTP_BAD_REQUEST
            unless $cgi->request_method eq 'POST';
    foreach ($cgi->param) {
        my $val = $cgi->param($_);
        #$self->inspect_register_value($_, $val);
        $logger->debug("$_ $val");       
    }
}

1;