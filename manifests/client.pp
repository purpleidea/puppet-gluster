# Simple? gluster module by James
# Copyright (C) 2010-2012  James Shubin
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

# XXX: try mounting with: glusterfs --volfile-server=<server-address> --volfile-id=<volume-name> <mount-point> --xlator-option='*dht*.assert-no-child-down=yes' 	# TODO: quotes or not?

#
# Example:
#
# gluster::client { "/my_share":
#	mount_point => "/gluster/my_share",
#	server      => "vip.acme.com",
#	rw          => true,
#	mounted     => true
# }
#
# would generate:
#
# mount -t glusterfs vip.acme.com:/my_share /gluster/my_share
#
define gluster::client(
	$server,		# NOTE: use a vip as server hostname
	$mount_point = "",	# If you want to override the mount point, specify it here. Defaults to /share_name.
	$rw = false,		# mount read only (true) or rw (false)
#	$suid = false,		# mount with suid (true) or nosuid (false)	# TODO: will this work with gluster ?
	$mounted = true		# useful if we want to pull in the group
				# defs, but not actually mount (testing)
) {
	include gluster::client::base

	if ($mount_point == "") {
		$local_path = $name
	} else {
		$local_path = $mount_point
	}

	$rw_bool = $rw ? {
		true => 'rw',
		default => 'ro',
	}

	# TODO: will this work with gluster ?
	#$suid_bool = $suid ? {
	#	true => 'suid',
	#	default => 'nosuid',
	#}

	$mounted_bool = $mounted ? {
		true => mounted,
		default => unmounted,
	}

	# make an empty directory for the mount point
	exec { "mkdir -p ${local_path}":
		creates => $local_path,
		alias   => "create-local-gluster-path"
	}

	# Mount Options:
	# * backupvolfile-server=server-name
	# * fetch-attempts=N (where N is number of attempts)
	# * log-level=loglevel
	# * log-file=logfile
	# * direct-io-mode=[enable|disable]
	# * ro (for readonly mounts)
	# * acl (for enabling posix-ACLs)
	# * worm (making the mount WORM - Write Once, Read Many type)
	# * selinux (enable selinux on GlusterFS mount
	mount { "${local_path}":
		atboot => true,
		ensure => $mounted_bool,
		device => "${server}:${name}",
		fstype => 'glusterfs',
		options => "defaults,_netdev,${rw_bool}",	# TODO: will $suid_bool work with gluster ?
		dump => '0',		# fs_freq: 0 to skip file system dumps
		pass => '0',		# fs_passno: 0 to skip fsck on boot
		require => [
			Package[['glusterfs', 'glusterfs-fuse']],
			Exec["create-local-gluster-path"],
			Exec['gluster-fuse'],	# ensure fuse is loaded
		],
	}
}

# vim: ts=8
