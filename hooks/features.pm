package Genesis::Hook::Features::OCFScheduler v2.1.0;

use strict;
use warnings;

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.9');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	for my $feature (split /\s+/, $ENV{GENESIS_REQUESTED_FEATURES}) {
		bail(
			"Cannot specify a virtual feature: please specify $feature without the ".
			"preceeding '+' to position it in the feature list."
		) if ($feature =~ /^\+(.*)$/);
		$self->add_feature($feature);
	}
	if ($self->has_feature('ocfp')) {
		if ($self->has_feature('internal-postgres')) {
			$self->add_feature('+internal-postgres')
		} else {
			$self->add_feature("external-postgres-vault")
		}
		$self->add_feature("cf-route-registrar")
	} else {
		$self->add_feature("+internal-postgres")
			unless $self->has_feature("external-postgres")
					|| $self->has_feature("external-postgres-vault")
	}

	$self->done([$self->build_features_list(
		virtual_features => [ "internal-postgres" ]
	)]);
}

1;
