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
	$ip = '',	# you can specify which ip address to use (if multiple)
	$uuid = '',	# if empty, puppet will attempt to use the gluster fact
	$password = ''	# if empty, puppet will attempt to choose one magically
) {
	include gluster::vardir

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	if ("${uuid}" != '') and (! ("${uuid}" =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/)) {
		fail("The chosen UUID: '${uuid}' is not valid.")
	}

	Gluster::Host[$name] -> Service['glusterd']	# glusterd requires host

	# if we're on itself
	if "${fqdn}" == "${name}" {

		$valid_ip = "${ip}" ? {
			'' => "${::gluster_host_ip}" ? {	# smart fact...
				'' => "${::ipaddress}",		# puppet picks!
				default => "${::gluster_host_ip}",	# smart
			},
			default => "${ip}",			# user selected
		}
		if "${valid_ip}" == '' {
			fail('No valid IP exists!')
		}

		# store the ip here so that it can be accessed by bricks...
		class { '::gluster::host::data':
			#name => $name,
			ip => "${valid_ip}",
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

		# if we manually *pick* a uuid, then store it too, so that it
		# sticks if we ever go back to using automatic uuids. this is
		# useful if a user wants to initially import uuids by picking
		# them manually, and then letting puppet take over afterwards
		if "${uuid}" != '' {
			file { "${vardir}/uuid/uuid":
				content => "${uuid}\n",
				owner => root,
				group => root,
				mode => 600,	# might as well...
				ensure => present,
				require => File["${vardir}/uuid/"],
			}
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
				seluser => 'system_u',
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
				seluser => 'system_u',
				notify => [
					# propagate the notify up
					File['/var/lib/glusterd/peers/'],
					Service['glusterd'],	# ensure reload
				],
			}
		}
	}

	# vrrp...
	$vrrp = $::gluster::server::vrrp
	if ( "${fqdn}" == "${name}" ) and $vrrp {

		$vip = $::gluster::server::vip
		if ! ($vip =~ /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/) {
			fail('You must specify a valid VIP to use with VRRP.')
		}

		file { "${vardir}/vrrp/":
			ensure => directory,	# make sure this is a directory
			recurse => true,	# recurse into directory
			purge => true,		# purge unmanaged files
			force => true,		# purge subdirs and links
			require => File["${vardir}/"],
		}

		# store so that a fact can figure out the interface and cidr...
		file { "${vardir}/vrrp/ip":
			content => "${valid_ip}\n",
			owner => root,
			group => root,
			mode => 600,	# might as well...
			ensure => present,
			require => File["${vardir}/vrrp/"],
		}

		# NOTE: this is a tag to protect the pass file...
		file { "${vardir}/vrrp/vrrp":
			content => "${password}" ? {
				'' => undef,
				default => "${password}",
			},
			owner => root,
			group => root,
			mode => 600,	# might as well...
			ensure => present,
			require => File["${vardir}/vrrp/"],
		}

		# NOTE: $name here should probably be the fqdn...
		@@file { "${vardir}/vrrp/vrrp_${name}":
			content => "${::gluster_vrrp}\n",
			tag => 'gluster_vrrp',
			owner => root,
			group => root,
			mode => 600,
			ensure => present,
		}

		File <<| tag == 'gluster_vrrp' |>> {	# collect to make facts
		}

		# this figures out the interface from the $valid_ip value
		$if = "${::gluster_vrrp_interface}"		# a smart fact!
		$cidr = "${::gluster_vrrp_cidr}"		# even smarter!
		$p = "${::gluster::server::password}" ? {	# shh secret...
			'' => "${::gluster_vrrp_password}",	# combined fact
			default => "${::gluster::server::password}",
		}
		# this fact is sorted, which is very, very important...!
		$fqdns_fact = "${::gluster_vrrp_fqdns}"		# fact !
		$fqdns = split($fqdns_fact, ',')		# list !

		if "${if}" != '' and "${cidr}" != '' and "${p}" != '' {

			keepalived::vrrp { 'VI_GLUSTER':	# TODO: groups!
				state => "${fqdns[0]}" ? {	# first in list
					'' => 'MASTER',		# list is empty
					"${fqdn}" => 'MASTER',	# we are first!
					default => 'BACKUP',	# other in list
				},
				interface => "${if}",
				mcastsrc => "${valid_ip}",
				# TODO: support configuring the label index!
				# label ethX:1 for first VIP ethX:2 for second...
				ipaddress => "${vip}/${cidr} dev ${if} label ${if}:1",
				# FIXME: this limits puppet-gluster to 256 hosts maximum
				priority => inline_template("<%= 255 - (@fqdns.index('${fqdn}') or 0) %>"),
				routerid => 42,	# TODO: support configuring it!
				advertint => 3,	# TODO: support configuring it!
				password => "${p}",
				#group => 'gluster',	# TODO: groups!
				watchip => "${vip}",
				shorewall_zone => "${::gluster::server::zone}",
				shorewall_ipaddress => "${valid_ip}",
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
			default => ["${valid_ip}"],
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
