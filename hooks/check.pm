package Genesis::Hook::Check::Scheduler;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook::Check);

# Import required functions
use Genesis qw/bail info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if CF integration is configured properly when using cf-route-registrar
  if ($env->has_feature('cf-route-registrar')) {
    # Check for CF exodus data
    my $cf_deployment_env = $env->lookup('params.cf_deployment_env', undef);

    if (!$cf_deployment_env) {
      $env->notify(
        error => "cf-route-registrar feature requires params.cf_deployment_env to be set [#R{FAILED}]"
      );
      $self->{ok} = 0;
    } else {
      my $exodus_path = $env->exodus_mount()."$cf_deployment_env/cf";
      if (!$env->vault->has($exodus_path)) {
        $env->notify(
          error => "CF exodus data not found at $exodus_path [#R{FAILED}]"
        );
        $self->{ok} = 0;
      } else {
        $env->notify(success => "CF integration configured correctly [#G{OK}]");
      }
    }
  }

  # Check for external postgres configuration
  if ($env->has_feature('external-postgres') || $env->has_feature('external-postgres-vault')) {
    my $postgres_host = $env->lookup('params.external_db.host', undef);

    if (!$postgres_host) {
      $env->notify(
        error => "External postgres feature requires params.external_db.host to be set [#R{FAILED}]"
      );
      $self->{ok} = 0;
    } else {
      $env->notify(success => "External postgres configuration found [#G{OK}]");
    }
  }

  # Return the final result
  if ($self->{ok}) {
    $env->notify(success => "environment checks [#G{OK}]");
  } else {
    $env->notify(error => "environment checks [#R{FAILED}]");
  }

  return $self->done($self->{ok});
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
