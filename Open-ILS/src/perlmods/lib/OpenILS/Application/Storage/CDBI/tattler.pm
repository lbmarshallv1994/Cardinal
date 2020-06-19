package OpenILS::Application::Storage::CDBI::tattler;
our $VERSION = 1;

#-------------------------------------------------------------------------------
package tattler;
use base qw/OpenILS::Application::Storage::CDBI/;
#-------------------------------------------------------------------------------

package tattler::ignore_list;
use base qw/tattler/;
__PACKAGE__->table('tattler_ignore_list');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw/report_name target_copy org_unit/);
#-------------------------------------------------------------------------------

1;