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
   else{
   my $calculator = OpenILS::Utils::VicinityCalculator->new($key);
   $calculator->calculate_distance_matrix();
   }
}

__PACKAGE__->register_method(
    method    => 'get_all_hubs',
    api_name  => 'open-ils.vicinity-calculator.shipping-hubs.retrieve',
    signature => {
        desc     => q/Retrieve a list of all shipping hubs/,
    }
);

sub get_all_hubs{
   my ($self) = @_;
   my $calculator = OpenILS::Utils::VicinityCalculator->new();
   $logger->info("retreiving org unit shipping hubs");
   return $calculator->get_all_hubs();    
}

__PACKAGE__->register_method(
    method    => 'get_hub_from_ou',
    api_name  => 'open-ils.vicinity-calculator.shipping-hub.retrieve',
    signature => {
        desc     => q/Retrieve a shipping hub from a given OU/,
    }
);

sub get_hub_from_ou{
   my ($self, $org_unit) = @_;
   my $calculator = OpenILS::Utils::VicinityCalculator::Matrix->new();
   $logger->info("retreiving org unit shipping hubs");
   return $calculator->get_hub_from_ou($org_unit);    
}

__PACKAGE__->register_method(
    method    => 'get_distance_between_shipping_hubs',
    api_name  => 'open-ils.vicinity-calculator.shipping-hubs.distance',
    signature => {
        desc     => q/Retrieve the distance between two shipping hubs/,
    }
);

sub get_distance_between_shipping_hubs {
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
1;