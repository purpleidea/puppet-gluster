# GlusterFS module by James
# Copyright (C) 2010-2013+ James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class gluster::params(
	# packages...
	$package_glusterfs = 'glusterfs',
	$package_glusterfs_fuse = 'glusterfs-fuse',
	$package_glusterfs_server = 'glusterfs-server',
	$package_glusterfs_api = 'glusterfs-api',

	$package_e2fsprogs = 'e2fsprogs',
	$package_xfsprogs = 'xfsprogs',
	$package_btrfsprogs = 'btrfs-progs',

	$package_python_argparse = 'python-argparse',
	$package_python_lxml = 'python-lxml',
	$package_fping = 'fping',

	# programs...
	$program_gluster = '/usr/sbin/gluster',

	$program_modprobe = '/sbin/modprobe',
	$program_lsmod = '/sbin/lsmod',

	$program_parted = '/sbin/parted',
	$program_pvcreate = '/sbin/pvcreate',
	$program_vgcreate = '/sbin/vgcreate',
	$program_lvcreate = '/sbin/lvcreate',
	$program_vgs = '/sbin/vgs',
	$program_lvs = '/sbin/lvs',
	$program_pvdisplay = '/sbin/pvdisplay',
	$program_vgdisplay = '/sbin/vgdisplay',
	#$program_lvdisplay = '/sbin/lvdisplay',
	$program_xfsadmin = '/usr/sbin/xfs_admin',
	$program_mkfs_xfs = '/sbin/mkfs.xfs',
	$program_mkfs_ext4 = '/sbin/mkfs.ext4',
	$program_mkfs_btrfs = '/sbin/mkfs.btrfs',

	$program_fping = '/usr/sbin/fping',
	$program_findmnt = '/bin/findmnt',
	$program_awk = '/bin/awk',

	# Owner/Group
	# TODO: see /manifests/mount/base.pp
	# $misc_owner_base_fuse_conf_file = 'root',
	# $misc_group_base_fuse_conf_file = 'root',
	$misc_owner_brick_fsuuid_file = 'root',
	$misc_group_brick_fsuuid_file = 'root',
	$misc_owner_brick_name_file = 'root',
	$misc_group_brick_name_file = 'root',
	$misc_owner_data_gluster_group_dir = 'root',
	$misc_group_data_gluster_group_dir = 'nobody',
	$misc_owner_host_gluster_info_file = 'root',
	$misc_group_host_gluster_info_file = 'root',
	$misc_owner_host_gluster_uuid_file = 'root',
	$misc_group_host_gluster_uuid_file = 'root',
	$misc_owner_host_peer_uuid_file = 'root',
	$misc_group_host_peer_uuid_file = 'root',
	$misc_owner_host_uuid_file = 'root',
	$misc_group_host_uuid_file = 'root',
	$misc_owner_host_vrrp_ip_file = 'root',
	$misc_group_host_vrrp_ip_file = 'root',
	$misc_owner_host_vrrp_name_file = 'root',
	$misc_group_host_vrrp_name_file = 'root',
	$misc_owner_host_vrrp_password_file = 'root',
	$misc_group_host_vrrp_password_file = 'root',
	$misc_owner_params_gluster_program_file = 'root',
	$misc_group_params_gluster_program_file = 'root',
	$misc_owner_server_glusterd_dir = 'root',
	$misc_group_server_glusterd_dir = 'root',
	$misc_owner_server_glusterd_vol_file = 'root',
	$misc_group_server_glusterd_vol_file = 'root',
	$misc_owner_server_glusterfs_dir = 'root',
	$misc_group_server_glusterfs_dir = 'root',
	$misc_owner_server_peers_file = 'root',
	$misc_group_server_peers_file = 'root',
	$misc_owner_server_sponge_file = 'root',
	$misc_group_server_sponge_file = 'nobody',
	$misc_owner_volume_create_file = 'root',
	$misc_group_volume_create_file = 'root',
	$misc_owner_vardir_gluster_tmp_dir = 'root',
	$misc_group_vardir_gluster_tmp_dir = 'nobody',
	$misc_owner_vardir_tmp_dir = 'root',
	$misc_group_vardir_tmp_dir = 'nobody',
	$misc_owner_xml_parse_file = 'root',
	$misc_group_xml_parse_file = 'nobody',

	# services...
	$service_glusterd = 'glusterd',

	# external modules...
	$include_puppet_facter = true,

	# Default directories
	# See http://manpages.ubuntu.com/manpages/trusty/man8/mount.glusterfs.8.html
	$misc_gluster_logs = '/var/log/glusterfs/',

	# misc...
	$misc_gluster_reload = '/sbin/service glusterd reload',
	$misc_gluster_repo = 'https://download.gluster.org/pub/gluster/glusterfs/',

	# the operatingsystemrelease string used in the repository URL.
	$misc_repo_operatingsystemrelease = "${operatingsystemrelease}",

	# comment...
	$comment = ''

) {
	if "${comment}" == '' {
		warning('Unable to load yaml data/ directory!')
	}

	$valid_include_puppet_facter = $include_puppet_facter ? {
		true => true,
		false => false,
		'true' => true,
		'false' => false,
		default => true,
	}

	if $valid_include_puppet_facter {
		include puppet::facter
		$factbase = "${::puppet::facter::base}"
		$hash = {
			'gluster_program_gluster' => $program_gluster,
		}
		# create a custom external fact!
		file { "${factbase}gluster_program.yaml":
			content => inline_template('<%= @hash.to_yaml %>'),
			owner => "${misc_owner_params_gluster_program_file}",
			group => "${misc_group_params_gluster_program_file}",
			mode => 644,		# u=rw,go=r
			ensure => present,
		}
	}
}

# vim: ts=8
