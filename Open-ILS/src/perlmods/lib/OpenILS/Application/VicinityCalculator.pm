package OpenILS::Application::VicinityCalculator;
use strict; 
use warnings;
use OpenILS::Application;
use base qw/OpenILS::Application/;
use OpenILS::Utils::VicinityCalculator;
use OpenSRF::Utils::SettingsClient;
use OpenSRF::Utils::Logger qw(:logger);

__PACKAGE__->register_method(
    method    => 'build_distance_matrix',
    api_name  => 'open-ils.vicinity-calculator.build-distance-matrix',
    api_level => 1,
    argc      => 1,
    stream    => 1,
    # Caller is given control over how often to receive responses.
    max_chunk_size => 0,
    signature => {
        desc     => q/Batch calculation of shipping hub distance matrix./,
        return => {desc => 'See API Options for return types'}
    }
);

sub build_distance_matrix{
   my ($self) = @_;
   my $config = OpenSRF::Utils::SettingsClient->new();
   my $key = $config->config_value(
                apps => 'open-ils.vicinity-calculator' => app_settings => 'key'
        );
   if($key == undef || $key == ''){
   $logger->error("No Maps API key has been set up in opensrf xml.");  
   }
   my $calculator = OpenILS::Utils::VicinityCalculator->new($key);
   $calculator->calculate_distance_matrix();
}

1;