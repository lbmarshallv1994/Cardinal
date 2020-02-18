#!perl
use strict;
use warnings;

use Test::More tests => 17;
diag("General hold targeter tests");

use OpenILS::Const qw/:const/;
use OpenILS::Utils::TestUtils;
use OpenILS::Application::AppUtils;
use OpenILS::Utils::CStoreEditor qw/:funcs/;
use Data::Dumper;

my $script = OpenILS::Utils::TestUtils->new();
my $U = 'OpenILS::Application::AppUtils';
my $e = new_editor();

$script->bootstrap;
$e->init;

sub target {
    return $U->simplereq(
        'open-ils.hold-targeter', 
        'open-ils.hold-targeter.target', 
        @_
    );
}


# == Targeting Concerto hold 67.  Title hold.

my $hold_id = 67;
my $result = target({hold => $hold_id});

ok($result->{success}, "Targeting hold $hold_id returned success");

# Concerto hold 67 targets record 70 with a pickup_lib of 4.  
# There are several viable copies with circ lib 4.
my $current_copy = $e->retrieve_asset_copy($result->{target});
is($current_copy->circ_lib.'', '4', 'Targeted copy lives at pickup lib');

my $maps = $e->search_action_hold_copy_map([
    {hold => $hold_id},
    {
        flesh => 2, 
        flesh_fields => {ahcm => ['target_copy'], acp => ['call_number']}
    }
]);

is(scalar(@$maps), 29, "Hold $hold_id has 29 mapped potential copies");

is(scalar(grep {$_->target_copy->call_number->record != 70} @$maps), 0,
    'All targeted copies belong to the targeted bib record');

# Retarget to confirm a new copy is selected and that the previously
# targeted item has a new entry in action.unfulfilled_hold_list.

$result = target({hold => $hold_id});

isnt($result->{target}, $current_copy->id, 
    'Second targeter run on hold 67 selected targeted a different copy');

my $unfulfilled = $e->search_action_unfulfilled_hold_list(
    {hold => $hold_id, current_copy => $current_copy->id})->[0];

isnt($unfulfilled, undef, 'Previous copy has unfulfilled hold entry');

my $prev_target = $result->{target};

$result = target({hold => $hold_id, soft_retarget_interval => '0s'});

is($result->{target}, $prev_target, 
    "Hold $hold_id target remains the same with soft_retarget_interval");

$maps = $e->search_action_hold_copy_map({hold => $hold_id});

is(scalar(@$maps), 29, 
    "Hold $hold_id retains 29 mapped potential copies with soft_retarget_interval");


# == Resource sharing title hold 264
#
# Hold 264 is a title hold with pickup lib 13, target 9
# test ensures that hold is fulfilled from the closest org unit (by physical distance)

$hold_id = 264;
my $hold_lib = 13;
$result = target({hold => $hold_id});

ok($result->{success}, "Targeting hold $hold_id returned success");
$current_copy = $e->retrieve_asset_copy($result->{target});
$maps = $e->search_action_hold_copy_map([
    {hold => $hold_id},
    {
        flesh => 2, 
        flesh_fields => {ahcm => ['target_copy'], acp => ['call_number']}
    }
]);
my @org_ids = map{$_->[2]->circ_lib} @$maps;
push @org_ids, $hold_lib;
    my %circ_hubs;
    my %hubs;
    my @sh = $e->json_query({
        select => [{column=>'org_unit'},{column=>'hub'}],
        from => [
            'actor.list_org_unit_ancestor_shipping_hub',@org_ids]
    });
        for my $ref (@sh) {
        for (@$ref){
        $circ_hubs{$_->{org_unit}} = $_->{hub};
        } 
        }
my @d = $e->json_query({
        select => {'aoushd' => [{column => 'dest_hub'},{column => 'distance'}]},
        from => 'aoushd',
        where => {'orig_hub'=>[$hold_lib],'dest_hub'=>[values(%circ_hubs)]},
        order_by => [
            {class => 'aoushd', field => 'distance', direction => 'ASC'},
        ]
    });
    
    my %matrix;
    my $min_dist;
    for my $ref (@d) {
        for (@$ref){
            if ($_->{'distance'} != 0){
            $matrix{$_->{'dest_hub'}}=$_->{distance};
            if(!defined($min_dist) || $min_dist > $_->{distance}){
                $min_dist = $_->{distance};
            }            
            }
        }
    }
    
$current_copy = $e->retrieve_asset_copy($result->{target});
is($matrix{$circ_hubs{$current_copy->circ_lib}}, $min_dist, 
    "Selected copy for $hold_id is the minimum distance ($min_dist miles) from OU $hold_lib");

# == Metarecord hold tests
#
# Concerto hold 263 is a metarecord hold with pickup_lib 4, target 42, and 
# holdable_format '{"0":[{"_attr":"mr_hold_format","_val":"score"}]}'.

$hold_id = 263;
$result = target({hold => $hold_id});

ok($result->{success}, "Targeting hold $hold_id returned success");

$current_copy = $e->retrieve_asset_copy($result->{target});
is($current_copy->circ_lib.'', '9', 'Targeted copy lives at pickup lib');

$maps = $e->search_action_hold_copy_map([
    {hold => $hold_id},
    {
        flesh => 2, 
        flesh_fields => {ahcm => ['target_copy'], acp => ['call_number']}
    }
]);

is(scalar(@$maps), 24, "Hold $hold_id has 24 mapped potential copies");

# Only 1 bib record (42) links to metarecord 42.  It also satisfies the 
# holdable_format criteria.
is(scalar(grep {$_->target_copy->call_number->record != 42} @$maps), 0,
    'All targeted copies belong to the targeted bib record');

# Bib 101 has mr_hold_format 'book'.  Link it to the targeted metabib
# and confirm the targeter does not select it.

$e->xact_begin;
my $mrmap_101 = $e->search_metabib_metarecord_source_map({source => 101})->[0];
my $orig_101_mr = $mrmap_101->metarecord;
$mrmap_101->metarecord(42);
$e->update_metabib_metarecord_source_map($mrmap_101) or die $e->die_event;

# Temporarily point the original bib (42) at another metarecord

my $mrmap_42 = $e->search_metabib_metarecord_source_map({source => 42})->[0];
my $orig_42_mr = $mrmap_42->metarecord;
$mrmap_42->metarecord(1);
$e->update_metabib_metarecord_source_map($mrmap_42) or die $e->die_event;
$e->xact_commit;

# This time no copies should be targeted, since no records match
# the holdable_formats criteria.
$result = target({hold => $hold_id});

isnt($result->{success}, 1, 
    'Unable to target MR hold without copies matching holdable_format');

$maps = $e->search_action_hold_copy_map({hold => $hold_id});

is(scalar(@$maps), 0, 
    'No potential copies exist that match the holdable_format criteria');

# Now remove the holdable format restriction and copies belonging to
# record 101 should now be acceptable potential copies.
$e->xact_begin;
my $hold = $e->retrieve_action_hold_request($hold_id);
$hold->clear_holdable_formats;
$e->update_action_hold_request($hold) or die $e->die_event;
$e->xact_commit;

$result = target({hold => $hold_id});

$current_copy = $e->retrieve_asset_copy([
    $result->{target},
    {flesh => 1, flesh_fields => {acp => ['call_number']}}
]);

is($current_copy->call_number->record.'', '101', 
    'Metarecord hold targeted after removing holdable_format restriction');

# Return the hold and bib records to their original metarecord state 
# for re-test-ability.
$e->xact_begin;
$hold->holdable_formats('{"0":[{"_attr":"mr_hold_format","_val":"score"}]}');
$e->update_action_hold_request($hold) or die $e->die_event;
$mrmap_101->metarecord($orig_101_mr);
$mrmap_42->metarecord(42);
$e->update_metabib_metarecord_source_map($mrmap_101) or die $e->die_event;
$e->update_metabib_metarecord_source_map($mrmap_42) or die $e->die_event;
$e->xact_commit;


