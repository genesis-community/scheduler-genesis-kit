#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Scheduler v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/info bail run/;
use Time::HiRes qw/gettimeofday/;
use JSON::PP;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # If using cf-route-registrar feature, check CF availability
  if ($env->has_feature('cf-route-registrar')) {
    $env->notify("Checking CF availability for cf-route-registrar feature...");

    my $cf_deployment_env = $env->lookup('params.cf_deployment_env', undef);
    if (!$cf_deployment_env) {
      bail(
        "cf-route-registrar feature requires params.cf_deployment_env to be set"
      );
    }

    # Check if CF exodus data exists
    my $exodus_path = $env->exodus_mount()."$cf_deployment_env/cf";
    if (!$env->vault->has($exodus_path)) {
      bail(
        "CF exodus data not found at $exodus_path. Please deploy CF first"
      );
    }

    info("CF integration validated successfully [#G{OK}]");
  }

  # If using external-postgres feature, check database availability
  if ($env->has_feature('external-postgres') || $env->has_feature('external-postgres-vault')) {
    $env->notify("Checking external PostgreSQL database availability...");

    my $postgres_host = $env->lookup('params.external_db.host', undef);
    if (!$postgres_host) {
      bail(
        "External postgres feature requires params.external_db.host to be set"
      );
    }

    # Additional validation could be done here, for example attempting to connect to the database

    info("External database configuration validated [#G{OK}]");
  }

  # Everything is good, let's proceed with the deployment
  $env->notify("#G{All pre-deployment checks passed}");

  # Create an empty file to record the pre-deploy state
  my $predeploy_data = {
    timestamp => time(),
    features => [$env->features],
  };

  return $self->done(encode_json($predeploy_data));
}

1;

