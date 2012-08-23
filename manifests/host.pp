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

# TODO: instead of peering manually this way (which makes the most sense, but
# might be unsupported by gluster) we could peer using the cli, and ensure that
# only the host holding the vip is allowed to execute cluster peer operations.

define gluster::host(
	$uuid
) {
	# if we're on itself
	if ( "${fqdn}" == "${name}" ) {
		# set a unique uuid per host
		file { '/var/lib/glusterd/glusterd.info':
			content => template('gluster/glusterd.info.erb'),
			owner => root,
			group => root,
			mode => 644,					# u=rw,go=r
			ensure => present,
			require => File['/var/lib/glusterd/'],
		}
	} else {
		# set uuid=
		exec { "/bin/echo 'uuid=${uuid}' >> '/var/lib/glusterd/peers/${uuid}'":
			logoutput => on_failure,
			unless => "/bin/grep -qF 'uuid=' '/var/lib/glusterd/peers/${uuid}'",
			notify => File['/var/lib/glusterd/peers/'],	# propagate the notify up
			before => File["/var/lib/glusterd/peers/${uuid}"],
			alias => "gluster-host-uuid-${name}",
			# FIXME: doing this causes a dependency cycle! adding
			# the Package[] require doesn't. It would be most
			# correct to require the peers/ folder, but since it's
			# not working, requiring the Package[] will still give
			# us the same result. (Package creates peers/ folder).
			# NOTE: it's possible the cycle is a bug in puppet or a
			# bug in the dependencies somewhere else in this module.
			#require => File['/var/lib/glusterd/peers/'],
			require => Package['glusterfs-server'],
		}

		# set state=
		exec { "/bin/echo 'state=3' >> '/var/lib/glusterd/peers/${uuid}'":
			logoutput => on_failure,
			unless => "/bin/grep -qF 'state=' '/var/lib/glusterd/peers/${uuid}'",
			notify => File['/var/lib/glusterd/peers/'],	# propagate the notify up
			before => File["/var/lib/glusterd/peers/${uuid}"],
			require => Exec["gluster-host-uuid-${name}"],
			alias => "gluster-host-state-${name}",
		}

		# set hostname1=...
		exec { "/bin/echo 'hostname1=${name}' >> '/var/lib/glusterd/peers/${uuid}'":
			logoutput => on_failure,
			unless => "/bin/grep -qF 'hostname1=' '/var/lib/glusterd/peers/${uuid}'",
			notify => File['/var/lib/glusterd/peers/'],	# propagate the notify up
			before => File["/var/lib/glusterd/peers/${uuid}"],
			require => Exec["gluster-host-state-${name}"],
		}

		# tag the file so it doesn't get removed by purge
		file { "/var/lib/glusterd/peers/${uuid}":
			ensure => present,
			notify => File['/var/lib/glusterd/peers/'],	# propagate the notify up
			owner => root,
			group => root,
			# NOTE: this mode was found by inspecting the process
			mode => 600,					# u=rw,go=
		}
	}
}

# vim: ts=8
