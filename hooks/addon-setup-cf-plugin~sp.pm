#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Scheduler::SetupCFPlugin v2.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

use Genesis qw/info run bail/;
use Genesis::UI qw/prompt_for_boolean/;
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
  "Adds the 'scheduler' plugin to the Cloud Foundry CLI.\n".
  "Supports the following options:\n".
  "[[  #y{-f}                 >>Force installation of the plugin, overwriting existing version";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options according to the proper pattern
  my %options = $self->parse_options([
    'f',   # Force installation of plugins
  ]);

  my $force = $options{f} ? 1 : 0;

  # Check if CF Community repository exists
  my ($out, $rc) = run('cf list-plugin-repos | grep -q CF-Community');
  if ($rc != 0) {
    info('Adding #G{Cloud Foundry Community} plugins repository...');
    # TODO: Check if run cmd fails and handle it
    run('cf add-plugin-repo CF-Community http://plugins.cloudfoundry.org');
  }

  # Check if scheduler plugin already exists
  ($out, $rc) = run('cf plugins | grep -q OCFScheduler');

  # Store existing version for comparison
  my $existing = "";
  if ($rc == 0) {
    ($existing) = run('cf plugins --checksum | grep OCFScheduler | tr -s \' \' | cut -d \' \' -f 2');
    chomp($existing);
  }

  # Install plugin
  info("\n#Wkiu{Attempting to install latest version of the starkandwayne/ocf-scheduler-cf-plugin...}\n");

  my $cmd = 'cf install-plugin -r starkandwayne ocf-scheduler-cf-plugin';
  $cmd .= ' -f' if $force;

  run($cmd);

  # Check if we successfully installed the plugin
  ($out, $rc) = run('cf plugins | grep -q OCFScheduler');
  if ($rc != 0) {
    info("\nFailed to install the scheduler plugin.");
    return $self->done(0);
  }

  # Check if we updated the plugin
  my $updated = "";
  ($updated) = run('cf plugins --checksum | grep OCFScheduler | tr -s \' \' | cut -d \' \' -f 2');
  chomp($updated);

  if ($existing eq $updated && $existing ne "") {
    info("\nNo update - existing ocf-scheduler-cf-plugin remains at version $existing\n");
    return $self->done(1);
  }

  # Display success message
  my $action = $existing ? "updated" : "installed";

  # Display plugin header and details
  my ($header) = run('cf plugins | head -n3 | tail -n1');
  chomp($header);

  my ($separator) = run('echo "$1" | sed -e \'s/[^ ] [^ ]/xxx/g\' | sed -e \'s/[^ ]/-/g\'', $header);
  chomp($separator);

  my ($plugin_line) = run('cf plugins | grep OCFScheduler');
  chomp($plugin_line);

  info(
    "\n$header\n$separator\n$plugin_line\n".
    "\n#G{[OK]} Successfully $action starkandwayne ocf-scheduler-cf-plugin.".
    "\n\tYou can run #c{cf uninstall-plugin OCFScheduler} to remove it.\n"
  );

	return $self->done();
}

1;
