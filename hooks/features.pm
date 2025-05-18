#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Scheduler v2.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  for my $feature (@{$self->{features}}) {
    if ($feature =~ /^\+(.*)$/) {
      bail(
        "Cannot specify a virtual feature: please specify $1 without the ".
        "preceding '+' to position it in the feature list."
      );
    } else {
      $self->add_feature($feature);
    }
  }

  # Handle postgres database selection
  if ($self->has_feature('ocfp')) {
    if ($self->has_feature('internal-postgres')) {
      $self->add_feature('+internal-postgres');
    } else {
      $self->add_feature("external-postgres-vault");
    }
    $self->add_feature("cf-route-registrar");
  } else {
    # Default to internal postgres unless external is specified
    $self->add_feature("+internal-postgres")
    unless $self->has_feature("external-postgres")
    || $self->has_feature("external-postgres-vault");
  }

  $self->done([$self->build_features_list(
        virtual_features => [ "internal-postgres" ]
      )]);
}

1;
