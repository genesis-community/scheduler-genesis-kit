#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::Scheduler v2.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::PostDeploy);

use Genesis qw/info/;
use Time::HiRes qw/gettimeofday/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Only proceed if deployment was successful
  if ($self->deploy_successful) {
    $env->notify(
      "\n#M{$ENV{GENESIS_ENVIRONMENT}} Scheduler deployed!\n".
      "\nTo use this Scheduler, you need to:\n".
      "\n1. Set up the Scheduler CF plugin:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do setup-cf-plugin}\n".
      "\n2. Bind the Scheduler service broker to your CF:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do bind-scheduler}\n".
      "\n3. Create and manage scheduler instances:\n".
      "\t#G{cf create-service scheduler dedicated my-scheduler}\n".
      "\t#G{cf create-service-key my-scheduler my-scheduler-key}\n".
      "\t#G{cf service-key my-scheduler my-scheduler-key}\n".
      "\n4. Run smoke tests (optional):\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do smoke-tests}\n"
    );
  }

  # Call parent class methods
  $self->SUPER::perform() if $self->can('SUPER::perform');

	return $self->done();
}

1;
