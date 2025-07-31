package Genesis::Hook::Addon::Scheduler::BindScheduler;

use v5.20;
use warnings; # Genesis min perl version is 5.20

use Genesis qw/info run bail/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return
  "Binds the Scheduler service broker to your deployed Cloud Foundry.\n".
  "Requires that you have the CF CLI installed and configured.\n";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	$self->cf_login();

	my $broker_username = $env->exodus_lookup("service_broker_username")
		or bail("Could not find service_broker_username in exodus data");

	my $broker_password = $env->exodus_lookup("service_broker_password")
		or bail("Could not find service_broker_password in exodus data");

	my $domain = $env->exodus_lookup("service_broker_domain")
		or bail("Could not find service_broker_domain in exodus data");

	my $url = "https://$domain";

	my ($out, $rc, $err) = run(
		'cf create-service-broker scheduler "$1" "$2" "$3"',
		$broker_username, $broker_password, $url
	);

	if ($rc != 0) {
		# Check if it's just because it already exists
		if ($err && $err =~ /service broker name is taken/) {
			info("\nService broker already exists, updating it instead...");
			run(
				{onfailure => "Failed to update service broker"},
				'cf update-service-broker scheduler "$1" "$2" "$3"',
				$broker_username, $broker_password, $url
			);
		} else {
			bail("Failed to create service broker: $err");
		}
	}

	run(
		{onfailure => "Failed to enable service access for scheduler"},
		'cf enable-service-access scheduler')
	;

	info("\n#G{[OK]} Successfully created and configured the scheduler service broker.");

	return $self->done();
}

sub cf_login {
	my ($self) = @_;
	my $env = $self->env;
	my $cf_deployment_env = $env->name;
	my $cf_deployment_type = "cf";

	# Determine exodus target
	my $cf_target = sprintf(
		"%s/%s",
		$env->lookup('params.cf_deployment_env', $env->name),
		$env->lookup('params.cf_deployment_type', 'cf')
	);
	# Get exodus from target - default to empty hash if not found
	my $cf_exodus = $env->exodus_lookup('.',{},$cf_target);

	my ($out, $rc) = run('cf plugins | grep -q \'^cf-targets\'');
	my $use_cf_targets = ($rc == 0);

	if (!$use_cf_targets) {
		info(
			"\n#Y{The cf-targets plugin does not seem to be installed}".
			"\nInstall it first, via 'genesis do $cf_deployment_env -- setup-cli'".
			"\nfrom your $cf_deployment_env environment in your CF deployment repo.\n"
		);
		bail("CF targets plugin is required");
	}

	my $system_domain = $cf_exodus->{system_domain};
	my $username = $cf_exodus->{admin_username};
	my $password = $cf_exodus->{admin_password};
	my $api_url = "https://".$cf_exodus->{api_domain};

	bail("Could not find system_domain in CF exodus data") unless $system_domain;
	bail("Could not find admin_username in CF exodus data") unless $username;
	bail("Could not find admin_password in CF exodus data") unless $password;

	info("\n");
	run(
		{onfailure => "Failed to set CF API endpoint"},
		'cf api "$1" --skip-ssl-validation',
		$api_url
	);
	info("\n");
	run(
		{onfailure => "Failed to authenticate with CF"},
		'cf auth "$1" "$2"',
		$username, $password
	);
	info("\n");
	run(
		{onfailure => "Failed to save CF target"},
		'cf save-target -f "$1"',
		$cf_deployment_env
	);
	info("\n");
	run(
		{onfailure => "Failed to set CF target"},
		'cf target'
	);
	info("\n");

	return 1;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
