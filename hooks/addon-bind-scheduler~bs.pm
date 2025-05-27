#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Scheduler::BindScheduler v2.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

use Genesis qw/info run bail/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
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

  # Log in to CF first
  $self->cf_login();

  # Get broker credentials from exodus data
  my $broker_username = $env->exodus_lookup("service_broker_username");
  my $broker_password = $env->exodus_lookup("service_broker_password");
  my $domain = $env->exodus_lookup("service_broker_domain");

  # Check if we got all the credentials
  bail("Could not find service_broker_username in exodus data") unless $broker_username;
  bail("Could not find service_broker_password in exodus data") unless $broker_password;
  bail("Could not find service_broker_domain in exodus data") unless $domain;

  my $url = "https://$domain";

  # Create the service broker
  my ($out, $rc, $err) = run('cf create-service-broker scheduler "$1" "$2" "$3"',
                             $broker_username, $broker_password, $url);

  if ($rc != 0) {
    # Check if it's just because it already exists
    if ($err && $err =~ /service broker name is taken/) {
      info("\nService broker already exists, updating it instead...");
      run('cf update-service-broker scheduler "$1" "$2" "$3"',
          $broker_username, $broker_password, $url);
    } else {
      bail("Failed to create service broker: $err");
    }
  }

  # Enable access to the service
  run('cf enable-service-access scheduler');

  info("\n#G{[OK]} Successfully created and configured the scheduler service broker.");

	return $self->done();
}

sub cf_login {
  my ($self) = @_;
  my $env = $self->env;

  # Get CF deployment info from env or params
  my $cf_deployment_env = $env->lookup('params.cf_deployment_env', undef);
  bail("CF deployment environment not specified in params.cf_deployment_env")
    unless $cf_deployment_env;

  my $cf_deployment_type = "cf";  # Default to "cf"

  # Construct CF exodus path
  my $cf_exodus_path = $env->exodus_mount()."$cf_deployment_env/$cf_deployment_type";

  # Check for CF targets plugin
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

  # Get CF login info from vault
  my $system_domain = $self->vault->get("$cf_exodus_path:system_domain");
  bail("Could not find system_domain in CF exodus data") unless $system_domain;

  my $api_url = "https://api.$system_domain";
  my $username = $self->vault->get("$cf_exodus_path:admin_username");
  bail("Could not find admin_username in CF exodus data") unless $username;


  my $password = $self->vault->get("$cf_exodus_path:admin_password");
  bail("Could not find admin_password in CF exodus data") unless $password;

  # Log in to CF
  # TODO:Check if the command errored and handle it
  run('cf api "$1" --skip-ssl-validation', $api_url);
  run('cf auth "$1" "$2"', $username, $password);
  run('cf save-target -f "$1"', $cf_deployment_env);

  info("\n");
  run('cf target');

  return 1;
}

1;
