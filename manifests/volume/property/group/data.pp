# GlusterFS module by James
# Copyright (C) 2012-2013+ James Shubin
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

# NOTE: this provides an internal repository of volume parameter set groups and
# can be useful if the version of glusterfs does not have set group support, or
# if this module wants to distribute some custom groups which are not upstream.

class gluster::volume::property::group::data() {

	include gluster::vardir

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	file { "${vardir}/groups/":
		source => 'puppet:///modules/gluster/groups/',
		ensure => directory,
		recurse => true,
		purge => true,
		force => true,
		owner => root,
		group => nobody,
		mode => 644,			# u=rwx
		backup => false,		# don't backup to filebucket
		require => File["${vardir}/"],
	}
}

# vim: ts=8
