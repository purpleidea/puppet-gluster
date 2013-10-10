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

define gluster::volume(
	$bricks = [],
	$transport = 'tcp',
	$replica = 1,
	$stripe = 1,
	$vip = '',		# vip of the cluster (optional but recommended)
	$ping = true,		# do we want to include fping checks ?
	$start = undef		# start volume ? true, false (stop it) or undef
) {
	include gluster::xml
	include gluster::vardir
	include gluster::volume::base
	if $ping {
		include gluster::volume::ping
	}

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	# TODO: if using rdma, maybe we should pull in the rdma package... ?
	$valid_transport = $transport ? {
		'rdma' => 'rdma',
		'tcp,rdma' => 'tcp,rdma',
		default => 'tcp',
	}

	$valid_replica = $replica ? {
		'1' => '',
		default => "replica ${replica} ",
	}

	$valid_stripe = $stripe ? {
		'1' => '',
		default => "stripe ${stripe} ",
	}

	$valid_vip = "${vip}" ? {
		'' => $::gluster::server::vip,
		default => "${vip}",
	}

	# returns interface name that has vip, or '' if none are found.
	$vipif = inline_template("<%= interfaces.split(',').find_all {|x| '${valid_vip}' == scope.lookupvar('ipaddress_'+x) }[0,1].join('') %>")

	#Gluster::Brick[$bricks] -> Gluster::Volume[$name]	# volume requires bricks

	# get the bricks that match our fqdn, and append /$name to their path.
	# return only these paths, which can be used to build the volume dirs.
	# NOTE: gluster v3.4 won't create a volume if this dir already exists.
	# TODO: is this needed when bricks are devices and not on filesystem ?
	#$volume_dirs = split(inline_template("<%= bricks.find_all{|x| x.split(':')[0] == '${fqdn}' }.collect {|y| y.split(':')[1].chomp('/')+'/${name}' }.join(' ') %>"), ' ')
	#file { $volume_dirs:
	#	ensure => directory,		# make sure this is a directory
	#	recurse => false,		# don't recurse into directory
	#	purge => false,			# don't purge unmanaged files
	#	force => false,			# don't purge subdirs and links
	#	before => Exec["gluster-volume-create-${name}"],
	#	require => Gluster::Brick[$bricks],
	#}

	# add /${name} to the end of each: brick:/path entry
	$brick_spec = inline_template("<%= bricks.collect {|x| ''+x.chomp('/')+'/${name}' }.join(' ') %>")

	# if volume creation fails for a stupid reason, in many cases, glusterd
	# already did some of the work and left us with volume name directories
	# on all bricks. the problem is that the future volume create commands,
	# will error if they see that volume directory already present, so when
	# we error we should rmdir any empty volume dirs to keep it pristine...
	# TODO: this should be a gluster bug... we must hope it doesn't happen!
	# maybe related to: https://bugzilla.redhat.com/show_bug.cgi?id=835494
	$rmdir_volume_dirs = sprintf("/bin/rmdir '%s'", inline_template("<%= bricks.find_all{|x| x.split(':')[0] == '${fqdn}' }.collect {|y| y.split(':')[1].chomp('/')+'/${name}/' }.join('\' \'') %>"))

	# get the list of bricks fqdn's that don't have our fqdn
	$others = inline_template("<%= bricks.find_all{|x| x.split(':')[0] != '${fqdn}' }.collect {|y| y.split(':')[0] }.join(' ') %>")

	$fping = sprintf("/usr/sbin/fping -q %s", $others)
	$status = sprintf("/usr/sbin/gluster peer status --xml | ${vardir}/xml.py connected %s", $others)

	$onlyif = $ping ? {
		false => "${status}",
		default => [
			"${fping}",
			"${status}",
		],
	}

	$require = $ping ? {
		false => [
			Service['glusterd'],
			File["${vardir}/volume/create-${name}.sh"],
			File["${vardir}/xml.py"],	# status check
			Gluster::Brick[$bricks],
		],
		default => [
			Service['glusterd'],
			File["${vardir}/volume/create-${name}.sh"],
			Package['fping'],
			File["${vardir}/xml.py"],	# status check
			Gluster::Brick[$bricks],
		],
	}

	# run if vip not defined (bypass mode) or if vip exists on this machine
	if ("${valid_vip}" == '' or "${vipif}" != '') {

		# store command in a separate file to run as bash...
		# NOTE: we sleep for 5 seconds to give glusterd a chance to
		# settle down first if we're doing a hot (clean) puppet run
		file { "${vardir}/volume/create-${name}.sh":
			content => inline_template("#!/bin/bash\n/bin/sleep 5s && /usr/sbin/gluster volume create ${name} ${valid_replica}${valid_stripe}transport ${valid_transport} ${brick_spec} > >(/usr/bin/tee '/tmp/gluster-volume-create-${name}.stdout') 2> >(/usr/bin/tee '/tmp/gluster-volume-create-${name}.stderr' >&2) || (${rmdir_volume_dirs} && /bin/false)\nexit \$?\n"),
			owner => root,
			group => root,
			mode => 755,
			ensure => present,
			require => File["${vardir}/volume/"],
		}

		# NOTE: This should only happen on one host!
		# NOTE: There's maybe a theoretical race condition if this runs
		# at exactly the same time on more than one host. That's why it
		# is advisable to use a vip.
		# NOTE: This could probably fail on at least N-1 nodes (without
		# vip) or one (the vip node, when using vip) before it succeeds
		# because it shouldn't work until all the bricks are available,
		# which per node will happen right before this runs.
		# fping all the other nodes to ensure they're up for creation
		# TODO: consider piping in a /usr/bin/yes to avoid warnings...
		# NOTE: in this command, we save the std{out,err} and pass them
		# on too for puppet to consume. we save in /tmp for fast access
		# EXAMPLE: gluster volume create test replica 2 transport tcp annex1.example.com:/storage1a/test annex2.example.com:/storage2a/test annex3.example.com:/storage3b/test annex4.example.com:/storage4b/test annex1.example.com:/storage1c/test annex2.example.com:/storage2c/test annex3.example.com:/storage3d/test annex4.example.com:/storage4d/test
		exec { "gluster-volume-create-${name}":
			command => "${vardir}/volume/create-${name}.sh",
			logoutput => on_failure,
			unless => "/usr/sbin/gluster volume list | /bin/grep -qxF '${name}' -",	# add volume if it doesn't exist
			onlyif => $onlyif,
			#before => TODO?,
			require => $require,
			alias => "gluster-volume-create-${name}",
		}
	}

	# run if vip not defined (by pass mode) or vip exists on this machine
	if ("${valid_vip}" == '' or "${vipif}" != '') {
		if $start == true {
			# try to start volume if stopped
			exec { "/usr/sbin/gluster volume start ${name}":
				logoutput => on_failure,
				onlyif => "/usr/sbin/gluster volume list | /bin/grep -qxF '${name}' -",
				unless => "/usr/sbin/gluster volume status ${name}",	# returns false if stopped
				require => Exec["gluster-volume-create-${name}"],
				alias => "gluster-volume-start-${name}",
			}
		} elsif ( $start == false ) {
			# try to stop volume if running
			# NOTE: this will still succeed even if a client is mounted
			# NOTE: This uses `yes` to workaround the: Stopping volume will
			# make its data inaccessible. Do you want to continue? (y/n)
			# TODO: http://community.gluster.org/q/how-can-i-make-automatic-scripts/
			# TODO: gluster --mode=script volume stop ...
			exec { "/usr/bin/yes | /usr/sbin/gluster volume stop ${name}":
				logoutput => on_failure,
				onlyif => "/usr/sbin/gluster volume status ${name}",	# returns true if started
				require => Exec["gluster-volume-create-${name}"],
				alias => "gluster-volume-stop-${name}",
			}
		} else {	# 'undef'-ined
			# don't manage volume run state
		}
	}

	$shorewall = $::gluster::server::shorewall
	if $shorewall {
		$zone = $::gluster::server::zone	# firewall zone

		$ips = $::gluster::server::ips		# override host ip list
		$ip = $::gluster::host::data::ip	# ip of brick's host...
		$source_ips = type($ips) ? {
			'array' => inline_template("<%= (ips+[]).uniq.delete_if {|x| x.empty? }.join(',') %>"),
			default => ["${ip}"],
		}

		$port = getvar("gluster_ports_volume_${name}")	# fact !

		# NOTE: we need to add the $fqdn so that exported resources
		# don't conflict... I'm not sure they should anyways though
		@@shorewall::rule { "gluster-volume-${name}-${fqdn}":
			action => 'ACCEPT',
			source => "${zone}",	# override this on collect...
			source_ips => $source_ips,
			dest => '$FW',
			proto => 'tcp',
			port => "${port}",	# comma separated string or list
			#comment => "${fqdn}",
			comment => 'Allow incoming tcp port from glusterfsds.',
			tag => 'gluster_firewall_volume',
			ensure => present,
		}
		# we probably shouldn't collect the above rule from our self...
		#Shorewall::Rule <<| tag == 'gluster_firewall_volume' and comment != "${fqdn}" |>> {
		Shorewall::Rule <<| tag == 'gluster_firewall_volume' |>> {
			source => "${zone}",	# use our source zone
			before => Service['glusterd'],
		}
	}
}

# vim: ts=8
