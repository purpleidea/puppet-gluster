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

# NOTE: thanks to Joe Julian for: http://community.gluster.org/q/what-is-the-command-that-someone-can-run-to-get-the-value-of-a-given-property/

define gluster::volume::property(
	$value,
	$vip = '',		# vip of the cluster (optional but recommended)
	$autotype = true		# set to false to disable autotyping
) {
	include gluster::xml
	include gluster::vardir
	include gluster::volume::property::data

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	$split = split($name, '#')	# do some $name parsing
	$volume = $split[0]		# volume name
	$key = $split[1]		# key name

	if ! ( "${volume}#${key}" == "${name}" ) {
		fail('The property $name must match a $volume#$key pattern.')
	}

	# split out $etype and $jchar lookup into a separate file
	$etypes = $::gluster::volume::property::data::etypes
	$jchars = $::gluster::volume::property::data::jchars

	# transform our etypes into short etypes (missing the prefix)
	# TODO: we should see if there are duplicates (collisions)
	# if there are collisions, and a gluster volume set group type contains
	# one of these keys, then it's ambiguous and it's clearly a gluster bug
	$short_etypes_yaml = inline_template('<%= @etypes.inject({}) {|h, (x,y)| h[ (x.index(".").nil?? x : x[x.index(".")+1..-1]) ] = y; h }.to_yaml %>')
	$short_jchars_yaml = inline_template('<%= @jchars.inject({}) {|h, (x,y)| h[ (x.index(".").nil?? x : x[x.index(".")+1..-1]) ] = y; h }.to_yaml %>')
	$short_etypes = parseyaml($short_etypes_yaml)
	$short_jchars = parseyaml($short_jchars_yaml)

	# FIXME: a short key should lookup the equivalent in the normal table,
	# and vice-versa, and set an alias so that you can't define a short
	# key and a long key at the same time which refer to the same variable!

	# expected type
	if has_key($etypes, "${key}") {
		$etype = $etypes["${key}"] ? {
			'' => 'undefined',
			default => $etypes["${key}"],
		}
	# the keys of these etypes are missing their prefix up to the first '.'
	} elsif has_key($short_etypes, "${key}") {
		$etype = $short_etypes["${key}"] ? {
			'' => 'undefined',
			default => $short_etypes["${key}"],
		}
	} else {
		$etype = 'undefined'
	}

	if (! $autotype) {
		if type($value) != 'string' {
			fail('Expecting type(string) if autotype is disabled.')
		}
		$safe_value = shellquote($value)	# TODO: is this the safe thing?

	# if it's a special offon type and of an acceptable value
	} elsif ($etype == 'offon') {	# default is off
		if type($value) == 'boolean' {
			$safe_value = $value ? {
				true => 'on',
				default => 'off',
			}

		} elsif type($value) == 'string' {
			$downcase_value = inline_template('<%= @value.downcase %>')
			$safe_value = $downcase_value ? {
				'on' => 'on',
				#'off' => 'off',
				default => 'off',
			}

		} else {
			fail("Gluster::Volume::Property[${key}] must be type: ${etype}.")
		}

	# if it's a special onoff type and of an acceptable value
	} elsif ($etype == 'onoff') {	# default is on
		if type($value) == 'boolean' {
			$safe_value = $value ? {
				false => 'off',
				default => 'on',
			}

		} elsif type($value) == 'string' {
			$downcase_value = inline_template('<%= @value.downcase %>')
			$safe_value = $downcase_value ? {
				'off' => 'off',
				#'on' => 'on',
				default => 'on',
			}

		} else {
			fail("Gluster::Volume::Property[${key}] must be type: ${etype}.")
		}
	} elsif $etype == 'integer' {
		# TODO: we could also add range and/or set validation
		$safe_value = inline_template('<%= [Fixnum, String].include?(@value.class) ? @value.to_i : "null" %>')
		if "${safe_value}" == 'null' {	# value was of an invalid type!
			fail("Gluster::Volume::Property[${key}] must be type: ${etype}.")
		}

	} elsif $etype == 'string' {
		$safe_value = shellquote($value)	# TODO: is this the safe thing?

	# if it's not a string and it's not the expected type, fail
	} elsif ( type($value) != $etype ) {	# type() from puppetlabs-stdlib
		fail("Gluster::Volume::Property[${key}] must be type: ${etype}.")

	# convert to correct type
	} else {

		if $etype == 'string' {
			$safe_value = shellquote($value)	# TODO: is this the safe thing?
		} elsif $etype == 'array' {

			# join char
			if has_key($jchars, "${key}") {
				$jchar = $jchars["${key}"]
			} elsif has_key($short_jchars, "${key}") {
				$jchar = $short_jchars["${key}"]
			} else {
				$jchar = ''
			}

			$safe_value = inline_template('<%= @value.join(jchar) %>')
		#} elsif ... {	# TODO: add more conversions here if needed

		} else {
			fail("Unknown type: ${etype}.")
		}
	}

	$valid_vip = "${vip}" ? {
		'' => $::gluster::server::vip,
		default => "${vip}",
	}

	# returns interface name that has vip, or '' if none are found.
	$vipif = inline_template("<%= @interfaces.split(',').find_all {|x| '${valid_vip}' == scope.lookupvar('ipaddress_'+x) }[0,1].join('') %>")

	# run if vip not defined (bypass mode) or if vip exists on this machine
	if ("${valid_vip}" == '' or "${vipif}" != '') {
		# volume set <VOLNAME> <KEY> <VALUE>
		# set a volume property only if value doesn't match what is available
		# FIXME: check that the value we're setting isn't the default
		# FIXME: you can check defaults with... gluster volume set help | ...
		exec { "/usr/sbin/gluster volume set ${volume} ${key} ${safe_value}":
			unless => "/usr/bin/test \"`/usr/sbin/gluster volume --xml info ${volume} | ${vardir}/xml.py property --key '${key}'`\" = '${safe_value}'",
			onlyif => "/usr/sbin/gluster volume list | /bin/grep -qxF '${volume}' -",
			logoutput => on_failure,
			require => [
				Gluster::Volume[$volume],
				File["${vardir}/xml.py"],
			],
		}
	}
}

# vim: ts=8
