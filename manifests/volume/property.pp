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

	# expected type
	if has_key($etypes, "${key}") {
		$etype = $etypes["${key}"] ? {
			'' => 'undefined',
			default => $etypes["${key}"],
		}
	} else {
		$etype = 'undefined'
	}

	if (! $autotype) {
		if type($value) != 'string' {
			fail('Expecting type(string) if autotype is disabled.')
		}
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
			} else {
				$jchar = ''
			}

			$safe_value = inline_template('<%= value.join(jchar) %>')
		#} elsif ... {	# TODO: add more conversions here if needed

		} else {
			fail("Unknown type: ${etype}.")
		}
	}

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

# vim: ts=8
