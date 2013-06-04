# Simple? gluster module by James
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

class gluster::client::base {
	# TODO: ensure these are from our 'gluster' repo
	package { ['glusterfs', 'glusterfs-fuse']:
		ensure => present,
	}

	# FIXME: choose a reliable and correct way to ensure fuse is loaded
	#[root@test2 ~]# dmesg | grep -i fuse
	#[root@test2 ~]# modprobe fuse
	#[root@test2 ~]# dmesg | grep -i fuse
	#fuse init (API version 7.13)
	#[root@test2 ~]#

	# modprobe fuse if it's missing
	exec { '/sbin/modprobe fuse':
		logoutput => on_failure,
		onlyif => '/usr/bin/test -z "`/bin/dmesg | grep -i fuse`"',
		alias => 'gluster-fuse',
	}

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
