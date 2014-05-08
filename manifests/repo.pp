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

define gluster::repo(
	# if you specify 'x.y', it will find the latest x.y.*
	# if you specify 'x.y.z', it will stick to that version
	# anything omitted is taken to mean "latest"
	# if you leave this blank, we assume you want the latest version...
	$version = ''
) {
	include gluster::params

	$base = "${::gluster::params::misc_gluster_repo}"

	if "${version}" == '' {
		# latest
		$base_v = "${base}LATEST/"
	} else {
		notice("GlusterFS version: '${version}' was chosen.")

		# parse out the -release if it exists. example: 3.4.2-13.el6
		# \1 is the major/minor version, eg: 3.4.2
		# \2 is the release with a leading dash, eg: -13.el6
		# \3 is the first part of the release, eg: 13
		# \4 is the second part of the release, eg: el6
		$real_v = regsubst("${version}", '^([\d\.]*)(\-([\d]{1,})\.([a-zA-Z\d]{1,}))?$', '\1')

		# search for qa style releases
		$qa_pattern = '^([\d\.]*)(\-(0\.[\d]{1,}\.((alpha|beta|qa|rc)[\d]{1,}))\.([a-zA-Z\d]{1,}))?$'
		$qa_type = regsubst("${version}", "${qa_pattern}", '\5')
		$qa = "${qa_type}" ? {
			/(alpha|beta|qa|rc)/ => true,
			default => false,
		}

		if $qa {
			$qa_folder = regsubst("${version}", "${qa_pattern}", '\1\4')
			# look inside the qa-releases/ subfolder...
			$base_v = "${base}qa-releases/${qa_folder}/"

		} elsif "${real_v}" =~ /^(\d+)\.(\d+)$/ {		# x.y
			#$base_v = "${base}${1}.${2}/LATEST/"		# same!
			$base_v = "${base}${real_v}/LATEST/"

		} elsif "${real_v}" =~ /^(\d+)\.(\d+)\.(\d+)$/ {	# x.y.z
			#$base_v = "${base}${1}.${2}/${1}.${2}.${3}/"	# same!
			$base_v = "${base}${1}.${2}/${real_v}/"

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

	$base_arch = "${base_os}epel-${operatingsystemrelease}/"

	$gpgkey = "${base_os}pub.key"

	include ::yum

	#yum::repos::repo { "gluster-${arch}":
	yum::repos::repo { "${name}":
		baseurl => "${base_arch}${arch}/",
		enabled => true,
		gpgcheck => true,
		# XXX: this should not be an https:// link, it should be a file
		gpgkeys => ["${gpgkey}"],
		ensure => present,
	}

	# TODO: technically, i don't think this is needed yet...
	#yum::repos::repo { 'gluster-noarch':
	#	baseurl => "${base_arch}noarch/",
	#	enabled => true,
	#	gpgcheck => true,
	#	# XXX: this should not be an https:// link, it should be a file
	#	gpgkeys => ["${gpgkey}"],
	#	ensure => present,
	#}
}

# vim: ts=8
