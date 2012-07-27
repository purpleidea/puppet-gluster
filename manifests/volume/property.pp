# Simple? gluster module by James
# Copyright (C) 2010-2012  James Shubin
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
	$value
) {
	include gluster::volume::property::base

	$split = split($name, '#')	# do some $name parsing
	$volume = $split[0]		# volume name
	$key = $split[1]		# key name

	if ! ( "${volume}#${key}" == "${name}" ) {
		fail('The property $name must match a $volume#$key pattern.')
	}

	$safe_value = shellquote($value)	# TODO: is this the safe thing?

	# volume set <VOLNAME> <KEY> <VALUE>
	# set a volume property only if value doesn't match what is available
	# FIXME: check that the value we're setting isn't the default
	# FIXME: you can check defaults with... gluster volume set help | ...
	exec { "/usr/sbin/gluster volume set ${volume} ${key} ${safe_value}":
		unless => "/usr/bin/test \"`/usr/sbin/gluster volume --xml info ${volume} | ./xml.py ${key}`\" = '${safe_value}'",
		logoutput => on_failure,
		require => [
			Gluster::Volume[$volume],
			File['/var/lib/puppet/tmp/gluster/xml.py'],
		],
	}
}

# vim: ts=8
