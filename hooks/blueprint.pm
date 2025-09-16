package Genesis::Hook::Blueprint::Scheduler;

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

  # Handle database selection
  if ($self->want_feature("external-postgres")) {
    $self->add_files("manifests/external-postgres.yml");
  } elsif ($self->want_feature("external-postgres-vault")) {
    $self->add_files("manifests/external-postgres-vault.yml");
  } else {
    $self->add_files("manifests/releases/postgres.yml");
  }

  # Handle CF route registrar
  if ($self->want_feature("cf-route-registrar")) {
    $self->add_files(qw(
      manifests/releases/routing.yml
      manifests/cf-route-registrar.yml
    ));
  }

  # Add OCFP configuration if needed
  if ($self->want_feature("ocfp")) {
    $self->add_files("ocfp/ocfp.yml");
  }

  # Add any custom ops files
  foreach my $feature ($self->features) {
    next if $feature =~ /^(external-postgres.*|cf-route-registrar|ocfp|\+.*)$/;

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
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
