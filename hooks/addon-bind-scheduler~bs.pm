package Genesis::Hook::Addon::Scheduler::BindScheduler v1.1.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use Genesis qw/info run bail read_json_from/;
use File::Temp qw/tempdir/;

use parent qw(Genesis::Hook::Addon);

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');

	$obj->{cf_deployment_env}  = $obj->env->lookup('params.cf_deployment_env', $obj->env->name);
	$obj->{cf_deployment_type} = $obj->env->lookup('params.cf_deployment_type', 'cf');
	my $cf_target = sprintf("%s/%s", $obj->{cf_deployment_env}, $obj->{cf_deployment_type});
	# Get exodus from target - default to empty hash if not found
	$obj->{cf_exodus} = $obj->env->exodus_lookup('.', {}, $cf_target);

	return $obj;
}

sub cmd_details {
	return
	"Registers the Scheduler service broker with your deployed Cloud Foundry,\n".
	"and enables its service for the orgs listed in params.broker_orgs.\n".
	"The service is never enabled for every org.\n".
	"Requires that the CF CLI is installed, and that the environment uses the\n".
	"service-broker feature.\n".
	"Supports the following options:\n".
	"[[  #y{-o ORG}             >>Enable access for this org, and ignore params.broker_orgs. May be repeated\n".
	"[[  #y{--prune}            >>Disable access for any org that is not in the list";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	my %options = $self->parse_options(['o=s@', 'prune']);

	bail("This environment does not use the service-broker feature, so there is no broker to register.")
		unless $env->has_feature('service-broker');

	my $broker_url      = $env->exodus_lookup('broker_url')      or bail("Could not find broker_url in the scheduler exodus data. Deploy with the service-broker feature first.");
	my $broker_username = $env->exodus_lookup('broker_username') or bail("Could not find broker_username in the scheduler exodus data");
	my $broker_password = $env->exodus_lookup('broker_password') or bail("Could not find broker_password in the scheduler exodus data");
	my $broker_name     = $env->exodus_lookup('broker_name',  'scheduler');
	my $service_name    = $env->exodus_lookup('service_name', 'scheduler');

	my @orgs = $options{o} && @{$options{o}}
		? @{$options{o}}
		: @{$env->lookup('params.broker_orgs', [])};
	my %seen;
	@orgs = grep { !$seen{$_}++ } @orgs;

	# Keep the CF CLI state private to this run, so the admin login never
	# lands in the operator's own CF home.
	my $cf_home = tempdir('scheduler-bind-XXXXXX', TMPDIR => 1, CLEANUP => 1);
	chmod 0700, $cf_home;
	local $ENV{CF_HOME} = $cf_home;

	$self->cf_login();

	info("\nbroker_name: #C{%s}\nbroker_url:  #C{%s}\n", $broker_name, $broker_url);

	# The password travels in the environment, never on a command line.
	{
		local $ENV{CF_BROKER_PASSWORD} = $broker_password;
		run(
			{onfailure => "Failed to create or update the service broker", interactive => 1},
			'cf create-service-broker --update-if-exists "$1" "$2" "$3"',
			$broker_name, $broker_username, $broker_url
		);
	}

	foreach my $org (@orgs) {
		run(
			{onfailure => "Failed to enable service access for org $org", interactive => 1},
			'cf enable-service-access "$1" -b "$2" -o "$3"',
			$service_name, $broker_name, $org
		);
	}

	$self->prune(\@orgs, $broker_name, $service_name) if $options{prune};

	if (@orgs) {
		info("\n#G{[OK]} Registered the %s broker and enabled #C{%s} for: %s\n", $broker_name, $service_name, join(', ', @orgs));
	} else {
		info(
			"\n#G{[OK]} Registered the %s broker. No orgs can see the service yet.\n".
			"Add the orgs to #c{params.broker_orgs} and run this addon again, or pass #y{-o ORG}.\n",
			$broker_name
		);
	}

	return $self->done();
}

# prune - disable access for every org that is not in the wanted list {{{1
sub prune {
	my ($self, $wanted, $broker_name, $service_name) = @_;
	my %want = map { $_ => 1 } @$wanted;

	my ($out, $rc) = run(
		'cf curl "/v3/service_plans?service_broker_names=$1&service_offering_names=$2" 2>/dev/null',
		$broker_name, $service_name
	);
	bail("Failed to list the service plans for the %s broker", $broker_name) if $rc;
	my $plans = eval { read_json_from($out) } or bail("Could not read the service plan list");

	foreach my $plan (@{$plans->{resources} || []}) {
		next unless ($plan->{visibility_type} // '') eq 'organization';
		my ($vis_out, $vis_rc) = run('cf curl "/v3/service_plans/$1/visibility" 2>/dev/null', $plan->{guid});
		bail("Failed to read plan visibility") if $vis_rc;
		my $vis = eval { read_json_from($vis_out) } or bail("Could not read the plan visibility");

		foreach my $org (@{$vis->{organizations} || []}) {
			next if $want{$org->{name}};
			run(
				{onfailure => "Failed to disable service access for org $org->{name}", interactive => 1},
				'cf disable-service-access "$1" -b "$2" -o "$3"',
				$service_name, $broker_name, $org->{name}
			);
			info("Disabled access for org #C{%s}\n", $org->{name});
		}
	}
}

# }}}

# cf_login - log in as the CF admin from the CF exodus data {{{1
sub cf_login {
	my ($self) = @_;

	my $system_domain = $self->{cf_exodus}{system_domain}
		or bail("Could not find system_domain in CF exodus data");
	my $username = $self->{cf_exodus}{admin_username}
		or bail("Could not find admin_username in CF exodus data");
	my $password = $self->{cf_exodus}{admin_password}
		or bail("Could not find admin_password in CF exodus data");

	run(
		{onfailure => "Failed to set CF API endpoint", interactive => 1},
		'cf api "$1" --skip-ssl-validation',
		"https://api.$system_domain"
	);

	# cf auth reads the credentials from these variables when it is given none.
	local $ENV{CF_USERNAME} = $username;
	local $ENV{CF_PASSWORD} = $password;
	run(
		{onfailure => "Failed to authenticate with CF", interactive => 1},
		'cf auth'
	);

	return 1;
}

# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
