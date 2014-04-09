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
	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

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

	package { ['glusterfs', 'glusterfs-fuse']:
		ensure => "${version}" ? {
			'' => present,
			default => "${version}",
		},
		before => Package['glusterfs-api'],
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
	exec { '/sbin/modprobe fuse':
		logoutput => on_failure,
		onlyif => '/usr/bin/test -z "`/bin/dmesg | /bin/grep -i fuse`"',
		alias => 'gluster-fuse',
	}
	#exec { '/sbin/modprobe fuse':
	#	logoutput => on_failure,
	#	unless => "/sbin/lsmod | /bin/grep -q '^fuse'",
	#	alias => 'gluster-modprobe-fuse',
	#}

	# TODO: will this autoload the fuse module?
	#file { '/etc/modprobe.d/fuse.conf':
	#	content => "fuse\n",	# TODO: "install fuse /sbin/modprobe --ignore-install fuse ; /bin/true\n" ?
	#	owner => root,
	#	group => root,
	#	mode => 644,		# u=rw,go=r
	#	ensure => present,
	#}
}

# vim: ts=8
