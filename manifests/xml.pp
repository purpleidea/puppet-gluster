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

class gluster::xml {
	include gluster::vardir
	include gluster::params

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	# argparse is built into python on new platforms and isn't needed here!
	if "${::gluster::params::package_python_argparse}" != '' {
		package { "${::gluster::params::package_python_argparse}":
			ensure => present,
			before => File["${vardir}/xml.py"],
		}
	}

	# for parsing gluster xml output
	package { "${::gluster::params::package_python_lxml}":
		ensure => present,
		before => File["${vardir}/xml.py"],
	}

	file { "${vardir}/xml.py":
		source => 'puppet:///modules/gluster/xml.py',
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_nobody}",
		mode => 700,			# u=rwx
		backup => false,		# don't backup to filebucket
		ensure => present,
		require => File["${vardir}/"],
	}
}

# vim: ts=8
