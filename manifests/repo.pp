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

class gluster::repo(
	# if you specify 'x.y', it will find the latest x.y.*
	# if you specify 'x.y.z', it will stick to that version
	# anything omitted is taken to mean "latest"
	# if you leave this blank, we assume you want the latest version...
	$version = ''
) {
	# XXX: this should be https !
	$base = 'http://download.gluster.org/pub/gluster/glusterfs/'

	if "${version}" == '' {
		# latest
		$base_v = "${base}LATEST/"
	} else {
		if "${version}" =~ /^(\d+)\.(\d+)$/ {			# x.y
			#$base_v = "${base}${1}.${2}/LATEST/"		# same!
			$base_v = "${base}${version}/LATEST/"

		} elsif "${version}" =~ /^(\d+)\.(\d+)\.(\d+)$/ {	# x.y.z
			#$base_v = "${base}${1}.${2}/${1}.${2}.${3}/"	# same!
			$base_v = "${base}${1}.${2}/${version}/"
		} else {
			fail('The version string is invalid.')
		}
	}

	case $operatingsystem {
		'CentOS': {
			$base_os = "${base_v}CentOS/"
		}
		'RedHat': {
			$base_os = "${base_v}RHEL/"
		}
		#'Debian', 'Ubuntu': {
		#}
		default: {
			fail("Operating system: '${operatingsystem}' not yet supported.")
		}
	}

	$arch = "${architecture}" ? {
		'x86_64' => 'x86_64',
		'i386' => 'i386',
		'i486' => 'i386',
		'i586' => 'i386',
		'i686' => 'i386',
		default => '',
	}
	if "${arch}" == '' {
		fail("Architecture: '${architecture}' not yet supported.")
	}

	$base_arch = "${base_os}/epel-${operatingsystemrelease}/"

	$gpgkey = "${base_os}pub.key"

	include ::yum

	#yum::repos::repo { "gluster-${arch}":
	yum::repos::repo { 'gluster':
		baseurl => "${base_arch}/${arch}/",
		enabled => true,
		gpgcheck => true,
		# XXX: this should not be an http:// link, it should be a file!
		# XXX: it's not even https! how can you even prevent a mitm...!
		gpgkeys => ["${gpgkey}"],
		ensure => present,
	}

	# TODO: technically, i don't think this is needed yet...
	#yum::repos::repo { 'gluster-noarch':
	#	baseurl => "${base_arch}/noarch/",
	#	enabled => true,
	#	gpgcheck => true,
	#	# XXX: this should not be an http:// link, it should be a file!
	#	# XXX: it's not even https! how can you even prevent a mitm...!
	#	gpgkeys => ["${gpgkey}"],
	#	ensure => present,
	#}
}

# vim: ts=8
