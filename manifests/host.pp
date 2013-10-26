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

# TODO: instead of peering manually this way (which makes the most sense, but
# might be unsupported by gluster) we could peer using the cli, and ensure that
# only the host holding the vip is allowed to execute cluster peer operations.

define gluster::host(
	$ip = $::ipaddress,	# specify which ip address to use (if multiple)
	$uuid = ''	# if empty, puppet will attempt to use the gluster fact
) {
	include gluster::vardir

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	if ("${uuid}" != '') and "${uuid}" =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/) {
		fail("The chosen UUID: '${uuid}' is not valid.")
	}

	Gluster::Host[$name] -> Service['glusterd']	# glusterd requires host

	# if we're on itself
	if "${fqdn}" == "${name}" {

		# store the ip here so that it can be accessed by bricks...
		class { '::gluster::host::data':
			#name => $name,
			ip => "${ip}",
			fqdn => "${fqdn}",
		}

		# don't purge the uuid file generated within
		file { "${vardir}/uuid/":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => false,		# don't purge unmanaged files
			force => false,		# don't purge subdirs and links
			require => File["${vardir}/"],
		}

		$valid_uuid = "${uuid}" ? {
			# fact from the data generated in: ${vardir}/uuid/uuid
			'' => "${::gluster_uuid}",
			default => "${uuid}",
		}
		if "${valid_uuid}" == '' {
			fail('No valid UUID exists yet!')
		} else {
			# get shorter version string for loose matching...
			$gluster_main_version = regsubst(
				"${gluster_version}",		# eg: 3.4.0
				'^(\d+)\.(\d+)\.(\d+)$',	# int.int.int
				'\1.\2'				# print int.int
			)

			# TODO: add additional values to this table...
			$operating_version = "${gluster_version}" ? {
				'' => '',	# gluster not yet installed...
				# specific version matches go here...
				'3.4.0' => '2',
				default => "${gluster_main_version}" ? {
					# loose version matches go here...
					#'3.3' => '1',		# blank...
					'3.4' => '2',
					#'3.5' => '3',		# guessing...
					default => '-1',	# unknown...
				},
			}

			# this catches unknown gluster versions to add to table
			if "${operating_version}" == '-1' {
				warning("Gluster version '${gluster_version}' is unknown.")
			}

			# set a unique uuid per host, and operating version...
			file { '/var/lib/glusterd/glusterd.info':
				content => template('gluster/glusterd.info.erb'),
				owner => root,
				group => root,
				mode => 600,			# u=rw,go=r
				seltype => 'glusterd_var_lib_t',
				seluser => 'unconfined_u',
				ensure => present,
				notify => Service['glusterd'],
				require => File['/var/lib/glusterd/'],
			}

			# NOTE: $name here should probably be the fqdn...
			@@file { "${vardir}/uuid/uuid_${name}":
				content => "${valid_uuid}\n",
				tag => 'gluster_uuid',
				owner => root,
				group => root,
				mode => 600,
				ensure => present,
			}
		}

		File <<| tag == 'gluster_uuid' |>> {	# collect to make facts
		}

	} else {
		$valid_uuid = "${uuid}" ? {
			# fact from the data generated in: ${vardir}/uuid/uuid
			'' => getvar("gluster_uuid_${name}"),	# fact !
			default => "${uuid}",
		}
		if "${valid_uuid}" == '' {
			notice('No valid UUID exists yet.')	# different msg
		} else {
			# set uuid=
			exec { "/bin/echo 'uuid=${valid_uuid}' >> '/var/lib/glusterd/peers/${valid_uuid}'":
				logoutput => on_failure,
				unless => "/bin/grep -qF 'uuid=' '/var/lib/glusterd/peers/${valid_uuid}'",
				notify => [
					# propagate the notify up
					File['/var/lib/glusterd/peers/'],
					Service['glusterd'],	# ensure reload
				],
				before => File["/var/lib/glusterd/peers/${valid_uuid}"],
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
			exec { "/bin/echo 'state=3' >> '/var/lib/glusterd/peers/${valid_uuid}'":
				logoutput => on_failure,
				unless => "/bin/grep -qF 'state=' '/var/lib/glusterd/peers/${valid_uuid}'",
				notify => [
					# propagate the notify up
					File['/var/lib/glusterd/peers/'],
					Service['glusterd'],	# ensure reload
				],
				before => File["/var/lib/glusterd/peers/${valid_uuid}"],
				require => Exec["gluster-host-uuid-${name}"],
				alias => "gluster-host-state-${name}",
			}

			# set hostname1=...
			exec { "/bin/echo 'hostname1=${name}' >> '/var/lib/glusterd/peers/${valid_uuid}'":
				logoutput => on_failure,
				unless => "/bin/grep -qF 'hostname1=' '/var/lib/glusterd/peers/${valid_uuid}'",
				notify => [
					# propagate the notify up
					File['/var/lib/glusterd/peers/'],
					Service['glusterd'],	# ensure reload
				],
				before => File["/var/lib/glusterd/peers/${valid_uuid}"],
				require => Exec["gluster-host-state-${name}"],
			}

			# tag the file so it doesn't get removed by purge
			file { "/var/lib/glusterd/peers/${valid_uuid}":
				ensure => present,
				owner => root,
				group => root,
				# NOTE: this mode was found by inspecting the process
				mode => 600,			# u=rw,go=r
				seltype => 'glusterd_var_lib_t',
				seluser => 'unconfined_u',
				notify => [
					# propagate the notify up
					File['/var/lib/glusterd/peers/'],
					Service['glusterd'],	# ensure reload
				],
			}
		}
	}

	# firewalling...
	$shorewall = $::gluster::server::shorewall
	if ( "${fqdn}" == "${name}" ) and $shorewall {
		$zone = $::gluster::server::zone	# firewall zone
		$ips = $::gluster::server::ips		# override host ip list

		#$other_host_ips = inline_template("<%= ips.delete_if {|x| x == '${ipaddress}' }.join(',') %>")		# list of ips except myself
		#$all_ips = inline_template("<%= (ips+[vip]+clients).uniq.delete_if {|x| x.empty? }.join(',') %>")
		$source_ips = type($ips) ? {
			'array' => inline_template("<%= (ips+[]).uniq.delete_if {|x| x.empty? }.join(',') %>"),
			default => ["${ip}"],
		}

		@@shorewall::rule { "glusterd-management-${name}":
			action => 'ACCEPT',
			source => "${zone}",	# override this on collect...
			source_ips => $source_ips,
			dest => '$FW',
			proto => 'tcp',
			port => '24007',
			comment => 'Allow incoming tcp:24007 from each glusterd.',
			tag => 'gluster_firewall_management',
			ensure => present,
		}

		# NOTE: used by rdma
		@@shorewall::rule { "glusterd-rdma-${name}":
			action => 'ACCEPT',
			source => "${zone}",	# override this on collect...
			source_ips => $source_ips,
			dest => '$FW',
			proto => 'tcp',
			port => '24008',
			comment => 'Allow incoming tcp:24008 for rdma.',
			tag => 'gluster_firewall_management',
			ensure => present,
		}

		# TODO: is this only used for nfs?
		@@shorewall::rule { "gluster-tcp111-${name}":
			action => 'ACCEPT',
			source => "${zone}",	# override this on collect...
			source_ips => $source_ips,
			dest => '$FW',
			proto => 'tcp',
			port => '111',
			comment => 'Allow tcp 111.',
			tag => 'gluster_firewall_management',
			ensure => present,
		}

		# TODO: is this only used for nfs?
		# TODO: johnmark says gluster nfs udp doesn't work :P
		@@shorewall::rule { "gluster-udp111-${name}":
			action => 'ACCEPT',
			source => "${zone}",	# override this on collect...
			source_ips => $source_ips,
			dest => '$FW',
			proto => 'udp',
			port => '111',
			comment => 'Allow udp 111.',
			tag => 'gluster_firewall_management',
			ensure => present,
		}

		# TODO: this collects our own entries too... we could exclude
		# them but this isn't a huge issue at the moment...
		Shorewall::Rule <<| tag == 'gluster_firewall_management' |>> {
			source => "${zone}",	# use our source zone
			before => Service['glusterd'],
		}
	}
}

# vim: ts=8
