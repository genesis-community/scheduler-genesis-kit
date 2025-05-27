#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Scheduler::SmokeTests v2.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

use Genesis qw/info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
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

  info("\nRunning smoke tests for the Scheduler deployment...\n");

  # Run the smoke-tests errand using BOSH
  my $cmd = sprintf("%s bosh run-errand smoke-tests", $env->get_call_path_with_env);
  my ($out, $rc, $err) = run({interactive => 1}, $cmd);

  if ($rc != 0) {
    info("\n#R{[ERROR]} Smoke tests failed. Please check the output above for details.\n");
    return $self->done(0);
  }

  info("\n#G{[OK]} Smoke tests completed successfully.\n");
	return $self->done();
}

1;
