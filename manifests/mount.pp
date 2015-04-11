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

# XXX: try mounting with: glusterfs --volfile-server=<server-address> --volfile-id=<volume-name> <mount-point> --xlator-option='*dht*.assert-no-child-down=yes' 	# TODO: quotes or not?
define gluster::mount(
	$server,		# NOTE: use a vip as server hostname
	$rw = false,		# mount read only (true) or rw (false)
#	$suid = false,		# mount with suid (true) or nosuid (false)	# TODO: will this work with gluster ?
	$mounted = true,	# useful if we want to pull in the group
				# defs, but not actually mount (testing)
	$repo = true,		# add a repo automatically? true or false
	$version = '',		# pick a specific version (defaults to latest)
	$ip = '',		# you can specify which ip address to use (if multiple)
	$type = 'glusterfs',	# use 'glusterfs' or 'nfs'
	$shorewall = false,
	$owner = '',		# mount owner
	$group = '',		# mount group
) {
	include gluster::params

	#mount -t glusterfs brick1.example.com:/test /test
	#include gluster::mount::base
	#class { '::gluster::mount::base':
	#	repo => $repo,
	#	version => $version,
	#}
	$params = {
		'repo' => $repo,
		'version' => $version,
	}
	# because multiple gluster::mount types are allowed on the same server,
	# we include with the ensure_resource function to avoid identical calls
	ensure_resource('class', 'gluster::mount::base', $params)

	# eg: vip:/volume
	$split = split($server, ':')	# do some $server parsing
	$host = $split[0]		# host fqdn or ip (eg: vip)
	# NOTE: technically $path should be everything BUT split[0]. This
	# lets our $path include colons if for some reason they're needed.
	#$path = $split[1]		# volume
	# TODO: create substring function
	$path = inline_template("<%= '${server}'.slice('${host}'.length+1, '${server}'.length-'${host}'.length-1) %>")
	$short_path = sprintf("%s", regsubst($path, '\/$', ''))	# no trailing
	#$valid_path = sprintf("%s/", regsubst($path, '\/$', ''))
	$volume = sprintf("%s", regsubst($short_path, '^\/', ''))	# no leading

	if ! ( "${host}:${path}" == "${server}" ) {
		fail('The $server must match a $host:$path pattern.')
	}

	if ! ( "${host}:/${volume}" == "${server}" ) {
		fail('The $server must match a $host:/$volume pattern.')
	}

	$short_name = sprintf("%s", regsubst("${name}", '\/$', ''))	# no trailing
	$long_name = sprintf("%s/", regsubst("${name}", '\/$', ''))	# trailing...

	$valid_ip = "${ip}" ? {
		'' => "${::gluster_host_ip}" ? {	# smart fact...
			'' => "${::ipaddress}",		# puppet picks!
			default => "${::gluster_host_ip}",	# smart
		},
		default => "${ip}",			# user selected
	}
	if "${valid_ip}" == '' {
		fail('No valid IP exists!')
	}

	# TODO: review shorewall rules against nfs fstype mount option
	if $shorewall {
		$safename = regsubst("${name}", '/', '_', 'G')	# make /'s safe
		@@shorewall::rule { "glusterd-management-${fqdn}-${safename}":
		#@@shorewall::rule { "glusterd-management-${volume}-${fqdn}":
			action => 'ACCEPT',
			source => '',	# override this on collect...
			source_ips => ["${valid_ip}"],
			dest => '$FW',
			proto => 'tcp',
			port => '24007',
			comment => 'Allow incoming tcp:24007 from each glusterd.',
			tag => 'gluster_firewall_management',
			ensure => present,
		}

		# wrap shorewall::rule in a fake type so that we can add $match
		#@@shorewall::rule { "gluster-volume-${fqdn}-${safename}":
		@@gluster::rulewrapper { "gluster-volume-${fqdn}-${safename}":
			action => 'ACCEPT',
			source => '',	# override this on collect...
			source_ips => ["${valid_ip}"],
			dest => '$FW',
			proto => 'tcp',
			port => '',	# override this on collect...
			#comment => "${fqdn}",
			comment => 'Allow incoming tcp port from glusterfsds.',
			tag => 'gluster_firewall_volume',
			match => "${volume}",	# used for collection
			ensure => present,
		}
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
		false => unmounted,
		default => mounted,
	}

	# ensure parent directories exist
	exec { "gluster-mount-mkdir-${name}":
		command => "/bin/mkdir -p '${long_name}'",
		creates => "${long_name}",
		logoutput => on_failure,
		before => File["${long_name}"],
	}

	# make an empty directory for the mount point
	file { "${long_name}":			# ensure a trailing slash
		ensure => directory,		# make sure this is a directory
		recurse => false,		# don't recurse into directory
		purge => false,			# don't purge unmanaged files
		force => false,			# don't purge subdirs and links
		alias => "${short_name}",	# don't allow duplicates name's
		owner => "${owner}" ? {		# make sure owner is undef if not specified
			'' => undef,
			default => $owner,
		},
		group => "${group}" ? {		# make sure group is undef if not specified
			'' => undef,
			default => $group,
		}
	}

	# TODO: review packages content against nfs fstype mount option
	$packages = "${::gluster::params::package_glusterfs_fuse}" ? {
		'' => ["${::gluster::params::package_glusterfs}"],
		default => [
			"${::gluster::params::package_glusterfs}",
			"${::gluster::params::package_glusterfs_fuse}",
		],
	}

	$valid_type = "${type}" ? {
		'nfs' => 'nfs',
		default => 'glusterfs',
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
	# * selinux (enable selinux on GlusterFS mount)
	# XXX: consider mounting only if some exported resource, collected and turned into a fact shows that the volume is available...
	# XXX: or something... consider adding the notify => Poke[] functionality
	mount { "${short_name}":
		atboot => true,
		ensure => $mounted_bool,
		device => "${server}",
		fstype => "${valid_type}",
		options => "defaults,_netdev,${rw_bool}",	# TODO: will $suid_bool work with gluster ?
		dump => '0',		# fs_freq: 0 to skip file system dumps
		pass => '0',		# fs_passno: 0 to skip fsck on boot
		require => [
			Package[$packages],
			File["${long_name}"],	# the mountpoint
			Exec['gluster-fuse'],	# ensure fuse is loaded!
		],
	}
}

# vim: ts=8
