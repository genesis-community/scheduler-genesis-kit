package Genesis::Hook::CloudConfig::Scheduler v1.0.1;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	my $network_topology = $self->env->ocfp_config_lookup('net.topology', 'v2');
	my $config = $self->build_cloud_config({
			'networks' => [$network_topology eq 'v1' ? () :
				$self->network_definition('scheduler', strategy => 'ocfp',
					dynamic_subnets => {
						allocation => {
							size => 1,
							statics => 0,
						},
						cloud_properties_for_iaas => {
							aws => {
								#'net_id' => $self->network_reference('id'),
								'subnet' => $self->subnet_reference('id'),
								'security_groups' => $self->get_network_security_groups(),
							},
							openstack => {
								'net_id' => $self->network_reference('id'),
								'security_groups' => ['default']
							},
							stackit => {
								'net_id' => $self->network_reference('id'),
								'security_groups' => ['default']
							},
						},
					},
				)
			],
			'vm_types' => [
				$self->vm_type_definition('scheduler', cloud_properties_for_iaas => {
						aws => {
							'instance_type' => $self->for_scale({
									dev => 't3.medium',
									prod => 'm6i.large'
								}, 't3.medium'),
							'ephemeral_disk' => {
								'size' => $self->for_scale({
										dev => gigabytes(4),
										prod => gigabytes(16)
									}, gigabytes(4)),
								'type' => 'gp3',
								'encrypted' => $self->TRUE
							},
							'metadata_options' => {
								'http_tokens' => 'required'
							}
						},
						openstack => {
							'instance_type' => $self->for_scale({
									dev => 'g1.2',
									prod => 'g1.3'
								}, 'g1.2'),
							'boot_from_volume' => $self->TRUE,
							'root_disk' => {
								'size' => 30
							},
						},
						stackit => {
							'instance_type' => $self->for_scale({
									dev => 'g1a.1d',
									prod => 'c1a.4d'
								}, 'g1a.2d'),
							'boot_from_volume' => $self->TRUE,
							'root_disk' => {
								'size' => 30
							},
						},
					}
				),
				$self->vm_type_definition('smoke-test', cloud_properties_for_iaas => {
						openstack => {
							'instance_type' => $self->for_scale({
									dev => 'g1.2',
									prod => 'g1.3'
								}, 'g1.2'),
							'boot_from_volume' => $self->TRUE,
							'root_disk' => {
								'size' => 30
							},
						},
						stackit => {
							'instance_type' => $self->for_scale({
									dev => 'g1a.1d',
									prod => 'c1a.4d'
								}, 'g1a.2d'),
							'boot_from_volume' => $self->TRUE,
							'root_disk' => {
								'size' => 30
							},
						},
						aws => {
							'instance_type' => $self->for_scale({
									dev => 't3.medium',
									prod => 'm6i.large'
								}, 't3.medium'),
							'ephemeral_disk' => {
								'size' => $self->for_scale({
										dev => gigabytes(4),
										prod => gigabytes(16)
									}, gigabytes(4)),
								'type' => 'gp3',
								'encrypted' => $self->TRUE
							},
							'metadata_options' => {
								'http_tokens' => 'required'
							}
						},
					}
				),
			],
			'disk_types' => [
				$self->disk_type_definition('scheduler',
					common => {
						disk_size => $self->for_scale({
								dev => gigabytes(25),
								prod => gigabytes(50)
							}, gigabytes(30))
					},
					cloud_properties_for_iaas => {
						aws => {
							'type' => 'gp3',
							'encrypted' => $self->TRUE
						},
						openstack => {
							'type' => 'storage_premium_perf6',
						},
						stackit => {
							'type' => 'storage_premium_perf6',
						},
					},
				),
				$self->disk_type_definition('database',
					common => {
						disk_size => $self->for_scale({
								dev => gigabytes(50),
								prod => gigabytes(100)
							}, gigabytes(50))
					},
					cloud_properties_for_iaas => {
						aws => {
							'type' => 'gp3',
							'encrypted' => $self->TRUE
						},
						openstack => {
							'type' => 'storage_premium_perf6',
						},
						stackit => {
							'type' => 'storage_premium_perf6',
						},
					},
				),
			],
		}
	);

	$self->done($config);

	return 1;

}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
