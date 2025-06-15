# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::New::Scheduler;

use v5.20;
use warnings; # Genesis min perl version is 5.20

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::New);

use Genesis qw/run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Create environment file with basic structure
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">", $env_file or die "Cannot open $env_file for writing: $!";

  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features: []\n";
  print $fh "    #- external-postgres  # Use an external postgresql database\n";
  print $fh "    #- cf-route-registrar # Use CF Route registration @ scheduler.<system_domain>\n";
  print $fh "    #- my-ops-file        # Use a custom ops file at ops/my-ops-file.yml\n";
  print $fh "\n";

  # Generate and add the genesis_config_block
  my ($out, $rc) = run('genesis_config_block');
  print $fh $out;

  print $fh "params: {}\n";
  close $fh;

  # Mark the hook as done successfully
	return $self->done();
}

1;

