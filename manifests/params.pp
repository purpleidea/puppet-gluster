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

	$program_fping = '/usr/sbin/fping',
	$program_findmnt = '/bin/findmnt',

	# services...
	$service_glusterd = 'glusterd',

	# misc...
	$misc_gluster_reload = '/sbin/service glusterd reload',

	# comment...
	$comment = ''
) {
	if "${comment}" == '' {
		warning('Unable to load yaml data/ directory!')
	}

	include puppet::facter
	$factbase = "${::puppet::facter::base}"
	$hash = {
		'gluster_program_gluster' => $program_gluster,
	}
	# create a custom external fact!
	file { "${factbase}gluster_program.yaml":
		content => inline_template('<%= @hash.to_yaml %>'),
		owner => root,
		group => root,
		mode => 644,		# u=rw,go=r
		ensure => present,
	}
}

# vim: ts=8
