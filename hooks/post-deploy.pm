package Genesis::Hook::PostDeploy::Scheduler v1.0.1;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::PostDeploy);

use Genesis qw/info/;
use Time::HiRes qw/gettimeofday/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Only proceed if deployment was successful
  if ($self->deploy_successful) {
    info(
      "\n#M{$ENV{GENESIS_ENVIRONMENT}} Scheduler deployed!\n".
      "\nTo use this Scheduler, you need to:\n".
      "\n1. Set up the Scheduler CF plugin:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do setup-cf-plugin}\n".
      "\n2. Create and manage scheduled jobs using the CF CLI plugin:\n".
      "\t#G{cf create-job APP-NAME JOB-NAME COMMAND}\n".
      "\t#G{cf schedule-job JOB-NAME \"*/5 * * * *\"}\n".
      "\t#G{cf jobs}\n".
      "\n3. Run smoke tests (optional):\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do smoke-tests}\n".
      ($env->has_feature('service-broker')
        ? "\n4. Register the service broker and enable it for the orgs in params.broker_orgs:\n".
          "\t#G{$ENV{GENESIS_CALL_ENV} do bind-scheduler}\n".
          "\nWith the broker on, an app must be bound to a scheduler service instance\n".
          "before it can create jobs and calls.\n"
        : "\n#Y{Note:} Enable the service-broker feature to offer the scheduler as a\n".
          "marketplace service that developers can create and bind.\n")
    );
  }

	return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
