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

class gluster::vardir {	# module vardir snippet
	if "${::puppet_vardirtmp}" == '' {
		if "${::puppet_vardir}" == '' {
			# here, we require that the puppetlabs fact exist!
			fail('Fact: $puppet_vardir is missing!')
		}
		$tmp = sprintf("%s/tmp/", regsubst($::puppet_vardir, '\/$', ''))
		# base directory where puppet modules can work and namespace in
		file { "${tmp}":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => true,		# purge all unmanaged files
			force => true,		# also purge subdirs and links
			owner => root,
			group => nobody,
			mode => 600,
			backup => false,	# don't backup to filebucket
			#before => File["${module_vardir}"],	# redundant
			#require => Package['puppet'],	# no puppet module seen
		}
	} else {
		$tmp = sprintf("%s/", regsubst($::puppet_vardirtmp, '\/$', ''))
	}
	$module_vardir = sprintf("%s/gluster/", regsubst($tmp, '\/$', ''))
	file { "${module_vardir}":		# /var/lib/puppet/tmp/gluster/
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,			# purge all unmanaged files
		force => true,			# also purge subdirs and links
		owner => root, group => nobody, mode => 600, backup => false,
		require => File["${tmp}"],	# File['/var/lib/puppet/tmp/']
	}
}

# vim: ts=8
