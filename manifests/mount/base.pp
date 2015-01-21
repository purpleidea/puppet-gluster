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

class gluster::mount::base(
	$repo = true,		# add a repo automatically? true or false
	$version = ''		# pick a specific version (defaults to latest)
) {
	include gluster::vardir
	include gluster::params
	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	$log_short_name = sprintf("%s", regsubst("${::gluster::params::misc_gluster_logs}", '\/$', ''))	# no trailing
	$log_long_name = sprintf("%s/", regsubst("${::gluster::params::misc_gluster_logs}", '\/$', ''))	# trailing...

	# if we use ::mount and ::server on the same machine, this could clash,
	# so we use the ensure_resource function to allow identical duplicates!
	$rname = "${version}" ? {
		'' => 'gluster',
		default => "gluster-${version}",
	}
	if $repo {
		$params = {
			'version' => "${version}",
		}
		ensure_resource('gluster::repo', "${rname}", $params)
	}

	$packages = "${::gluster::params::package_glusterfs_fuse}" ? {
		'' => ["${::gluster::params::package_glusterfs}"],
		default => [
			"${::gluster::params::package_glusterfs}",
			"${::gluster::params::package_glusterfs_fuse}",
		],
	}
	package { $packages:
		ensure => "${version}" ? {
			'' => present,
			default => "${version}",
		},
		before => "${::gluster::params::package_glusterfs_api}" ? {
			'' => undef,
			default => Package["${::gluster::params::package_glusterfs_api}"],
		},
		require => $repo ? {
			false => undef,
			default => Gluster::Repo["${rname}"],
		},
	}

	$api_params = {
		'repo' => $repo,
		'version' => "${version}",
	}
	ensure_resource('class', 'gluster::api', $api_params)

	# FIXME: choose a reliable and correct way to ensure fuse is loaded
	# dmesg | grep -i fuse
	# modprobe fuse
	# dmesg | grep -i fuse
	#fuse init (API version 7.13)
	#

	# modprobe fuse if it's missing
	exec { "${::gluster::params::program_modprobe} fuse":
		logoutput => on_failure,
		onlyif => '/usr/bin/test -z "`/bin/dmesg | /bin/grep -i fuse`"',
		alias => 'gluster-fuse',
	}
	#exec { "${::gluster::params::program_modprobe} fuse":
	#	logoutput => on_failure,
	#	unless => "${::gluster::params::program_lsmod} | /bin/grep -q '^fuse'",
	#	alias => 'gluster-modprobe-fuse',
	#}

	# TODO: will this autoload the fuse module?
	#file { '/etc/modprobe.d/fuse.conf':
	#	content => "fuse\n",	# TODO: "install fuse ${::gluster::params::program_modprobe} --ignore-install fuse ; /bin/true\n" ?
	#	owner => "${::gluster::params::misc_owner_root}",
	#	group => "${::gluster::params::misc_group_root}",
	#	mode => 644,		# u=rw,go=r
	#	ensure => present,
	#}

	# ensure parent directories exist for log directory
	exec { "gluster-log-mkdir-${name}":
		command => "/bin/mkdir -p '${log_long_name}'",
		creates => "${log_long_name}",
		logoutput => on_failure,
		before => File["${log_long_name}"],
	}

	# make an empty directory for logs
	file { "${log_long_name}":          # ensure a trailing slash
		ensure => directory,            # make sure this is a directory
		recurse => false,               # don't recurse into directory
		purge => false,                 # don't purge unmanaged files
		force => false,                 # don't purge subdirs and links
		alias => "${log_short_name}",   # don't allow duplicates name's
	}

}

# vim: ts=8
