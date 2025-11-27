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
      "\n#Y{Note:} The bind-scheduler addon is not yet implemented as the upstream\n".
      "OCF Scheduler does not provide a CF Service Broker API.\n"
    );
  }

	return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
