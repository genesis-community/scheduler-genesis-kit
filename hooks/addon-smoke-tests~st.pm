package Genesis::Hook::Addon::Scheduler::SmokeTests;

use v5.20;
use warnings; # Genesis min perl version is 5.20

use Genesis qw/info run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return
  "\nRuns the smoke tests errand for the Scheduler deployment.\n".
  "This errand validates that the Scheduler service is functioning correctly.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  info("\nRunning smoke tests errand for the Scheduler deployment...\n");

	$env->bosh->run_errand("smoke-tests");

  info("\n#G{[OK]} Smoke tests completed successfully.\n");
	return $self->done();
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
