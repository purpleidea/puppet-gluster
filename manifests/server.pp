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

class gluster::server(
	$nfs = false,								# TODO
	$vip = '',	# vip of the cluster (optional but recommended)
	$vrrp = false,
	$password = '',	# global vrrp password to use
	$version = '',	# pick a specific version (defaults to latest)
	$repo = true,	# add a repo automatically? true or false
	$baseport = '',	# specify base port option as used in glusterd.vol file
	$rpcauthallowinsecure = false,	# needed in some setups in glusterd.vol
	$shorewall = false,
	$zone = 'net',								# TODO: allow a list of zones
	$ips = false,	# an optional list of ip's for each in hosts[]
	$clients = []	# list of allowed client ip's	# TODO: get from exported resources
) {
	$FW = '$FW'			# make using $FW in shorewall easier

	include gluster::vardir
	include gluster::params

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	# if we use ::mount and ::server on the same machine, this could clash,
	# so we use the ensure_resource function to allow identical duplicates!
	$rname = "${version}" ? {
		'' => 'gluster',
		default => "gluster-${version}",
	}
	if $repo {
		$params = {
			'version' => "${version}",
		}
		ensure_resource('gluster::repo', "${rname}", $params)
	}

	# this is meant to be replace the excellent sponge utility by sponge.py
	file { "${vardir}/sponge.py":		# for scripts needing: 'sponge'
		source => 'puppet:///modules/gluster/sponge.py',
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_nobody}",
		mode => 700,			# u=rwx
		backup => false,		# don't backup to filebucket
		ensure => present,
		before => Package["${::gluster::params::package_glusterfs_server}"],
		require => File["${vardir}/"],
	}

	package { "${::gluster::params::package_glusterfs_server}":
		ensure => "${version}" ? {
			'' => present,
			default => "${version}",
		},
		before => "${::gluster::params::package_glusterfs_api}" ? {
			'' => undef,
			default => Package["${::gluster::params::package_glusterfs_api}"],
		},
		require => $repo ? {
			false => undef,
			default => Gluster::Repo["${rname}"],
		},
	}

	$api_params = {
		'repo' => $repo,
		'version' => "${version}",
	}
	ensure_resource('class', 'gluster::api', $api_params)

	# NOTE: not that we necessarily manage anything in here at the moment...
	file { '/etc/glusterfs/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# TODO: eventually...
		purge => false,			# TODO: eventually...
		force => false,			# TODO: eventually...
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 644,
		#notify => Service["${::gluster::params::service_glusterd}"],	# TODO: ???
		require => Package["${::gluster::params::package_glusterfs_server}"],
	}

	# NOTE: this option can be useful for users of libvirt migration as in:
	# https://bugzilla.redhat.com/show_bug.cgi?id=987555
	$valid_baseport = inline_template('<%= [Fixnum, String].include?(@baseport.class) ? @baseport.to_i : 0 %>')

	$valid_rpcauthallowinsecure = $rpcauthallowinsecure ? {
		true => true,
		default => false,
	}

	file { '/etc/glusterfs/glusterd.vol':
		content => template('gluster/glusterd.vol.erb'),
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 644,			# u=rw,go=r
		ensure => present,
		require => File['/etc/glusterfs/'],
	}

	file { '/var/lib/glusterd/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# TODO: eventually...
		purge => false,			# TODO: eventually...
		force => false,			# TODO: eventually...
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 644,
		#notify => Service["${::gluster::params::service_glusterd}"],	# TODO: eventually...
		require => File['/etc/glusterfs/glusterd.vol'],
	}

	file { '/var/lib/glusterd/peers/':
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,
		force => true,
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 644,
		notify => Service["${::gluster::params::service_glusterd}"],
		require => File['/var/lib/glusterd/'],
	}

	if $vrrp {
		class { '::keepalived':
			start => true,
			shorewall => $shorewall,
		}
	}

	if $shorewall {
		# XXX: WIP
		#if type3x($ips) == 'array' {
		#	#$other_host_ips = inline_template("<%= ips.delete_if {|x| x == '${ipaddress}' }.join(',') %>")		# list of ips except myself
		#	$source_ips = inline_template("<%= (ips+clients).uniq.delete_if {|x| x.empty? }.join(',') %>")
		#	#$all_ips = inline_template("<%= (ips+[vip]+clients).uniq.delete_if {|x| x.empty? }.join(',') %>")

		#	$src = "${source_ips}" ? {
		#		'' => "${zone}",
		#		default => "${zone}:${source_ips}",
		#	}

		#$endport = inline_template('<%= 24009+hosts.count %>')
		#$nfs_endport = inline_template('<%= 38465+hosts.count %>')
		#shorewall::rule { 'gluster-24000':
		#	rule => "
		#	ACCEPT    ${src}    $FW    tcp    24009:${endport}
		#	",
		#	comment => 'Allow 24000s for gluster',
		#	before => Service["${::gluster::params::service_glusterd}"],
		#}

		#if $nfs {					# FIXME: TODO
		#	shorewall::rule { 'gluster-nfs': rule => "
		#	ACCEPT    $(src}    $FW    tcp    38465:${nfs_endport}
		#	", comment => 'Allow nfs for gluster'}
		#}
	}

	# start service only after the firewall is opened and hosts are defined
	service { "${::gluster::params::service_glusterd}":
		enable => true,		# start on boot
		ensure => running,	# ensure it stays running
		hasstatus => false,	# FIXME: BUG: https://bugzilla.redhat.com/show_bug.cgi?id=836007
		hasrestart => true,	# use restart, not start; stop
	}
}

# vim: ts=8
