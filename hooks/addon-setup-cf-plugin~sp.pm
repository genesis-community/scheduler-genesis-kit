package Genesis::Hook::Addon::Scheduler::SetupCFPlugin v1.0.1;

use v5.20;
use warnings;    # Genesis min perl version is 5.20

use Genesis     qw/info run bail/;
use Genesis::UI qw/prompt_for_boolean/;

# Only needed for development
BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME} . './.genesis/lib' }

use parent qw(Genesis::Hook::Addon);

sub init {
	my $class = shift;
	my $obj   = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub cmd_details {
	return "Downloads and installs the 'scheduler' plugin for the Cloud Foundry CLI\n" .
	  "from the official GitHub releases.\n" .
	  "Supports the following options:\n" .
	  "[[  #y{-f}                 >>Force installation of the plugin, overwriting existing version";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options according to the proper pattern
	my %options = $self->parse_options(
		[
			'f',    # Force installation of plugins (kept for backward compatibility)
		]
	);

	# Note: We always force installation to avoid TTY issues in automated environments

	# Determine platform
	my ($os) = run('uname -s | tr A-Z a-z');
	chomp($os);
	$os = 'darwin' if $os eq 'darwin';
	$os = 'linux'  if $os eq 'linux';

	# Determine architecture
	my ($arch) = run('uname -m');
	chomp($arch);
	$arch = 'amd64' if $arch eq 'x86_64';
	$arch = 'arm64' if $arch eq 'aarch64';

	# Get latest release version from GitHub API
	info("Fetching latest release information from GitHub...");
	my ( $version, $rc_api ) = run(
'curl -s https://api.github.com/repos/cloudfoundry-community/ocf-scheduler-cf-plugin/releases/latest | jq -r .tag_name'
	);
	chomp($version);

	if ( $rc_api != 0 || !$version || $version eq 'null' || $version eq q{} ) {
		bail("Failed to fetch or parse release version from GitHub API");
	}

	info("Latest release version: #G{$version}");

	# Check if scheduler plugin already exists
	my ( $out, $rc ) = run('cf plugins | grep -q OCFScheduler');

	# Store existing version for comparison
	my $existing = "";
	if ( $rc == 0 ) {
		($existing) =
		  run('cf plugins --checksum | grep OCFScheduler | tr -s \' \' | cut -d \' \' -f 2');
		chomp($existing);
	}

	# Construct download URL
	my $binary_name = "ocf-scheduler-cf-plugin-${version}-${os}-${arch}";
	my $download_url =
"https://github.com/cloudfoundry-community/ocf-scheduler-cf-plugin/releases/download/${version}/${binary_name}";

	info("\n#Wkiu{Attempting to install ocf-scheduler-cf-plugin $version for $os/$arch...}\n");

	# Download the plugin
	my $tmp_file = "/tmp/ocf-scheduler-cf-plugin-$$";
	info("Downloading plugin from #C{$download_url}...");
	( $out, $rc ) = run("curl -sL -f -o $tmp_file '$download_url'");

	if ( $rc != 0 ) {
		bail("Failed to download plugin from $download_url (HTTP error or file not found)");
	}

	if ( !-f $tmp_file || -z $tmp_file ) {
		bail("Downloaded file is missing or empty: $tmp_file");
	}

	# Check file type
	my ($file_info) = run("file $tmp_file");
	info("Downloaded file type: $file_info");

	# Make it executable
	run("chmod +x $tmp_file");

	# Install plugin - always use -f flag to avoid interactive prompt in non-TTY environment
	my $cmd = "cf install-plugin -f $tmp_file";

	info("Installing plugin with command: $cmd");
	( $out, $rc ) = run($cmd);

	# Check if installation failed
	if ( $rc != 0 ) {
		# Clean up temporary file before failing
		run("rm -f $tmp_file");
		info("\nPlugin installation failed with exit code $rc");
		info("Output: $out") if $out;
		return $self->done(0);
	}

	# Clean up temporary file
	run("rm -f $tmp_file");

	# Check if we successfully installed the plugin
	( $out, $rc ) = run('cf plugins | grep -q OCFScheduler');
	if ( $rc != 0 ) {
		info("\nFailed to install the scheduler plugin.");
		return $self->done(0);
	}

	# Check if we updated the plugin
	my $updated = "";
	($updated) = run('cf plugins --checksum | grep OCFScheduler | tr -s \' \' | cut -d \' \' -f 2');
	chomp($updated);

	if ( $existing eq $updated && $existing ne "" ) {
		info("\nNo update - existing ocf-scheduler-cf-plugin remains at version $existing\n");
		return $self->done(1);
	}

	# Display success message
	my $action = $existing ? "updated" : "installed";

	# Display plugin header and details
	my ($header) = run('cf plugins | head -n3 | tail -n1');
	chomp($header);

	my ($separator) =
	  run( 'echo "$1" | sed -e \'s/[^ ] [^ ]/xxx/g\' | sed -e \'s/[^ ]/-/g\'', $header );
	chomp($separator);

	my ($plugin_line) = run('cf plugins | grep OCFScheduler');
	chomp($plugin_line);

	info( "\n$header\n$separator\n$plugin_line\n" .
		  "\n#G{[OK]} Successfully $action ocf-scheduler-cf-plugin $version." .
		  "\n\tYou can run #c{cf uninstall-plugin OCFScheduler} to remove it.\n" );

	return $self->done();
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
