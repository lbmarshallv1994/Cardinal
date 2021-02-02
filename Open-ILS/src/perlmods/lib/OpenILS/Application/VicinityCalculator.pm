package OpenILS::Application::VicinityCalculator;
use strict; 
use warnings;
use OpenILS::Application;
use base qw/OpenILS::Application/;
use OpenILS::Utils::VicinityCalculator;
use OpenSRF::Utils::SettingsClient;
use OpenSRF::Utils::Logger qw(:logger);

sub get_api_key {
   my $config = OpenSRF::Utils::SettingsClient->new();
   my $key = $config->config_value(
                apps => 'open-ils.vicinity-calculator' => app_settings => 'key'
        );
   return $key;
}

__PACKAGE__->register_method(
    method    => 'build_distance_matrix',
    api_name  => 'open-ils.vicinity-calculator.build-distance-matrix',
    signature => {
        desc     => q/Batch calculation of shipping hub distance matrix./,
        return => {desc => 'See API Options for return types'}
    }
);

sub build_distance_matrix{
   my ($self) = @_;
   my $key = get_api_key();
   if(!defined($key) || $key eq ''){
       $logger->error("No Maps API key has been set up in opensrf xml.");  
       return undef;
   }
   else{
       my $calculator = OpenILS::Utils::VicinityCalculator->new($key);
       $calculator->calculate_distance_matrix();
   return 1;
   }
}

__PACKAGE__->register_method(
    method    => 'set_coords',
    api_name  => 'open-ils.vicinity-calculator.set-coords',
    signature => {
        desc     => q/Calculate the latitude and longitude of an org unit's associated addresses/,
    }
);

sub set_coords{
   my ($self, $client, $org_unit) = @_;
   my $key = get_api_key();
   my $calculator = OpenILS::Utils::VicinityCalculator->new($key);
   $logger->info("calculating org unit coordinates");
   return $calculator->set_coord_for_ou($org_unit);    
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
   my $key = get_api_key();
   if(!defined($key) || $key eq ''){
       $logger->error("No Maps API key has been set up in opensrf xml.");  
       return undef;
   }
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
    my $calculator = OpenILS::Utils::VicinityCalculator::Matrix->new();
    $logger->info("calculating org unit shipping hub distances");
    return $calculator->distance_between_hubs($origin_hub,$dest_hub);  
}
1;