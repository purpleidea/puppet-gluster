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

class gluster::server(
	$hosts = [],	# this should be a list of fqdn's			# TODO: we could easily just setup gluster/shorewall by ip address instead of hostname!
	$ips = [],	# this should be a list of ip's for each in hosts[]	# TODO: i would have rather this happen with a local dns resolver, but I can't figure out how to make one!	# NOTE: this can be overcome probably by using exported resources or dns names in shorewall (bad)
	$clients = [],	# list of allowed client ip's
	#$vip = '',	# vip of the cluster (optional, but recommended)
	$nfs = false,	# TODO
	$shorewall = false,
	$zone = 'net',			# TODO: allow a list of zones
	$allow = 'all'
) {
	# TODO: ensure these are from our 'gluster' repo
	package { 'glusterfs-server':
		ensure => present,
	}

	# NOTE: not that we necessarily manage anything in here at the moment...
	file { '/etc/glusterfs/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# TODO: eventually...
		purge => false,			# TODO: eventually...
		force => false,			# TODO: eventually...
		owner => root,
		group => root,
		mode => 644,
		#notify => Service['glusterd'],	# TODO: ???
		require => Package['glusterfs-server'],
	}

	file { '/etc/glusterfs/glusterd.vol':
		content => template('gluster/glusterd.vol.erb'),	# NOTE: currently no templating is being done
		owner => root,
		group => root,
		mode => 644,			# u=rw,go=r
		ensure => present,
		require => File['/etc/glusterfs/'],
	}

	file { '/var/lib/glusterd/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# TODO: eventually...
		purge => false,			# TODO: eventually...
		force => false,			# TODO: eventually...
		owner => root,
		group => root,
		mode => 644,
		#notify => Service['glusterd'],	# TODO: eventually...
		require => File['/etc/glusterfs/glusterd.vol'],
	}

	file { '/var/lib/glusterd/peers/':
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,
		force => true,
		owner => root,
		group => root,
		mode => 644,
		notify => Service['glusterd'],
		require => File['/var/lib/glusterd/'],
	}

	if $shorewall {
		if $allow == 'all' {
			$net = 'net'
		} else {
			$net = "net:${allow}"
		}
		# TODO: could the facter values help here ?
		#$other_host_ips = inline_template("<%= ips.delete_if {|x| x == '${ipaddress}' }.join(',') %>")		# list of ips except myself
		$source_ips = inline_template("<%= (ips+clients).uniq.delete_if {|x| x.empty? }.join(',') %>")
		#$all_ips = inline_template("<%= (ips+[vip]+clients).uniq.delete_if {|x| x.empty? }.join(',') %>")
		#$list_of_hosts_except_myself = split(inline_template("<%= host_list.delete_if {|x| x == '${fqdn}' }.join(' ') %>"), ' ')

		############################################################################
		#	ACTION      SOURCE DEST                PROTO DEST  SOURCE  ORIGINAL
		#	                                             PORT  PORT(S) DEST

		# TODO: I've never seen anything connect on 24008. Is it ever used?
		shorewall::rule { 'glusterd':
			rule => "
			ACCEPT        ${zone}:${source_ips}    $FW        tcp    24007:24008
			",
			comment => 'Allow incoming tcp:24007-24008 from each other glusterd or client.',
			before => Service['glusterd'],
		}

		# TODO: Use the correct port range
		shorewall::rule { 'glusterfsd-easyfw':
			rule => "
			ACCEPT        ${zone}:${source_ips}    $FW        tcp    24009:25009	# XXX: Use the correct port range
			",
			comment => 'Allow incoming tcp:24009-25009 from each other glusterfsd and clients.',
			before => Service['glusterd'],
		}

		# TODO: is this only used for nfs?
		shorewall::rule { 'gluster-111':
			rule => "
			ACCEPT        ${zone}:${source_ips}    $FW        tcp    111
			ACCEPT        ${zone}:${source_ips}    $FW        udp    111
			",
			comment => 'Allow tcp/udp 111.',
			before => Service['glusterd'],
		}

		# XXX: WIP
		#$endport = inline_template('<%= 24009+hosts.count %>')		# XXX: is there one brick per server or two ? what does 'brick' mean in the context of open ports?
		#$nfs_endport = inline_template('<%= 38465+hosts.count %>')	# XXX: is there one brick per server or two ? what does 'brick' mean in the context of open ports?
		#shorewall::rule { 'gluster-24000':
		#	rule => "
		#	ACCEPT        ${zone}    $FW        tcp    24007,24008
		#	ACCEPT        ${zone}    $FW        tcp    24009:${endport}
		#	",
		#	comment => 'Allow 24000s for gluster',
		#	before => Service['glusterd'],
		#}

		if $nfs {	# FIXME: TODO
			shorewall::rule { 'gluster-nfs': rule => "
			ACCEPT        $(net}    $FW        tcp    38465:${nfs_endport}
			", comment => 'Allow nfs for gluster'}
		}
	}

	# start service only after the firewall is opened and hosts are defined
	service { 'glusterd':
		enable => true,			# start on boot
		ensure => running,		# ensure it stays running
		hasstatus => false,		# FIXME: BUG: https://bugzilla.redhat.com/show_bug.cgi?id=836007
		hasrestart => true,		# use restart, not start; stop
		require => Gluster::Host[$hosts],
	}
}

