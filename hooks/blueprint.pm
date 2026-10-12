#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Blueprint::Scheduler v1.0.1;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{files} = [];
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	$self->add_files(qw(
		manifests/scheduler.yml
		manifests/releases/scheduler.yml
	));

	# Handle CF route registrar
	if ($self->want_feature(qr/^(?:cf-route-registrar|ocfp)$/)) {
		$self->add_files(qw(
			manifests/releases/routing.yml
			manifests/cf-route-registrar.yml
		));
	}

	# The broker needs its credential and the scheduler route; check.pm refuses
	# the feature without a route.
	if ($self->want_feature('service-broker')) {
		bail(
			"The #c{service-broker} feature requires the #c{cf-route-registrar} or #c{ocfp} " .
			"feature, because Cloud Controller reaches the broker through the scheduler route."
		) unless $self->want_feature(qr/^(?:cf-route-registrar|ocfp)$/);
		$self->add_files("manifests/service-broker.yml");
	}

	# Add OCFP configuration if needed
	if ($self->want_feature("ocfp")) {
		$self->add_files("ocfp/ocfp.yml");

		#TODO: Replace with detection of existence of trusted certs
		if ($self->iaas eq 'aws') {
			$self->add_files("manifests/trusted-certs.yml");
		}
	} else {
		$self->add_files("manifests/releases/postgres.yml");
	}

	if ($self->env->ocfp_config_lookup('net.topology', 'v2') eq 'v1') {
		$self->add_files("ocfp/network-v1.yml");
	}

	if ($self->want_feature("+internal-postgres")) {
		$self->add_files("manifests/releases/postgres.yml");
	} else {
		$self->add_files("manifests/external-postgres.yml");
	}

	# Ubuntu resolute stemcells (opt-in; the default stays ubuntu-noble).  Added
	# after every other fragment so that it wins over the stemcell default.
	if ($self->want_feature('resolute')) {
		my $env = $self->env;
		my $stemcell_os = $env->lookup('params.stemcell_os', 'ubuntu-resolute');
		bail(
			"The #c{resolute} feature sets the stemcell os to ubuntu-resolute, but " .
			"the environment sets #c{params.stemcell_os} to #R{%s}.  " .
			"Remove that parameter.", $stemcell_os
		) if $stemcell_os ne 'ubuntu-resolute';

		$self->add_files('manifests/resolute.yml');
		# The bpm release is only part of the manifest when the route registrar is.
		$self->add_files('manifests/resolute-bpm.yml')
			if $self->want_feature(qr/^(?:cf-route-registrar|ocfp)$/);
		# The postgres release is only deployed with the internal database.
		$self->add_files('manifests/resolute-postgres.yml')
			if $self->want_feature('+internal-postgres');
	} elsif ($self->env->lookup('params.stemcell_os', 'ubuntu-noble') eq 'ubuntu-resolute') {
		bail(
			"The environment sets #c{params.stemcell_os} to ubuntu-resolute " .
			"without the #c{resolute} feature.  Enable the feature and remove " .
			"that parameter."
		);
	}

	# Add any custom ops files
	foreach my $feature ($self->features) {
		next if $feature =~ /^(external-postgres.*|cf-route-registrar|ocfp|resolute|service-broker|\+.*)$/;

		my $ops_file = $self->env->path("ops/$feature.yml");
		if (-f $ops_file) {
			$self->add_files($ops_file);
		} else {
			bail(
				"The #c{%s} feature is invalid. See the manual for list of valid features.",
				$feature
			);
		}
	}

	return $self->done();
}

1;
