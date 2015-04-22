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
	$bricks = true,		# specify a list of bricks, or true for auto...
	$group = 'default',	# use this bricks group name if we auto collect
	$transport = 'tcp',
	$replica = 1,
	$stripe = 1,
	# TODO: maybe this should be called 'chained' => true/false, and maybe,
	# we can also specify an offset count for chaining, or other parameters
	$layout = '',		# brick layout to use (default, chained, etc...)
	$vip = '',		# vip of the cluster (optional but recommended)
	$ping = true,		# do we want to include fping checks ?
	$settle = true,		# do we want to run settle checks ?
	$again = true,		# do we want to use Exec['again'] ?
	$start = undef		# start volume ? true, false (stop it) or undef
) {
	include gluster::xml
	if $again {
		include gluster::again
	}
	include gluster::vardir
	include gluster::params
	include gluster::volume::base
	if $ping {
		include gluster::volume::ping
	}

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	$shorewall = $::gluster::server::shorewall

	$settle_count = 3		# three is a reasonable default!
	$maxlength = 3
	if $maxlength < $settle_count {
		fail('The $maxlength needs to be greater than or equal to the $settle_count.')
	}
	$are_bricks_collected = (type3x($bricks) == 'boolean' and ($bricks == true))
	# NOTE: settle checks are still useful even if we are using ping checks
	# the reason why they are still useful, is that they can detect changes
	# in the bricks, which might propagate slowly because of exported types
	# the fping checks can only verify that the individual hosts are alive!
	$settle_count_check = $are_bricks_collected ? {
		false => false,
		default => $settle ? {
			false => false,
			default => true,
		}
	}
	# TODO: implement settle_time_check
	$settle_time_check = $settle ? {
		false => false,
		default => true,
	}

	# clean up old fsm data when not in use, because parent $vardir purges!
	if $are_bricks_collected {
		include gluster::volume::fsm
		file { "${vardir}/volume/fsm/${name}/":
			ensure => directory,	# make sure this is a directory
			recurse => true,	# recurse into directory
			purge => false,		# don't purge unmanaged files
			force => false,		# don't purge subdirs and links
			require => File["${vardir}/volume/fsm/"],
		}
	}

	$gluster_brick_group_fact = getvar("gluster_brick_group_${group}")
	$collected_bricks = split($gluster_brick_group_fact, ',')
	# run the appropriate layout function here
	$ordered_brick_layout = $layout ? {
		'chained' => brick_layout_chained($replica, $collected_bricks),
		default => brick_layout_simple($replica, $collected_bricks),
	}

	$valid_bricks = type3x($bricks) ? {
		'boolean' => $bricks ? {
			true => $ordered_brick_layout,		# an array...
			default => [],				# invalid type
		},
		'array' => $bricks,
		default => [],					# invalid type
	}

	# helpful debugging!
	notice(inline_template('collected_bricks: <%= @collected_bricks.inspect %>'))
	notice(inline_template('valid_bricks: <%= @valid_bricks.inspect %>'))

	# NOTE: we're using the valid_bricks value here, and not the collected
	# value. while we only need the $collected value for settle detection,
	# the actual brick value is needed for future add/remove brick code...
	$valid_input = join($valid_bricks, ',')	# TODO: this should be pickled
	if $are_bricks_collected and "${valid_input}" == '' {
		notice('The gluster::brick collection is not ready yet.')
	}
	$last = getvar("gluster_volume_fsm_state_${name}")	# fact !
	$valid_last = "${last}" ? {
		# initialize the $last var to match the $input if it's empty...
		'' => "${valid_input}",
		default => "${last}",
	}
	if $are_bricks_collected and ("${valid_input}" != '') and ("${valid_last}" == '') {
		fail('Previous state is invalid.')	# fact was tampered with
	}

	# NOTE: the stack lists are left base64 encoded since we only care if they change! :P
	# NOTE: each element in stack is base64 encoded because they contain: ,
	$stack_fact = getvar("gluster_volume_fsm_stack_${name}")	# fact !
	$stack_full = split("${stack_fact}", ',')
	$stack_trim = "${maxlength}" ? {
		'-1' => $stack_full,	# unlimited
		#default => split(inline_template('<%= @stack_full[0,@maxlength.to_i.abs].join(",") %>'), ','),
		default => split(inline_template('<%= @stack_full[[@stack_full.size-@maxlength.to_i.abs,0].max,@maxlength.to_i.abs].join(",") %>'), ','),
	}

	$watch_fact = getvar("gluster_volume_fsm_watch_${name}")	# fact !
	$watch_full = split("${watch_fact}", ',')
	$watch_trim = "${maxlength}" ? {
		'-1' => $watch_full,	# unlimited
		#default => split(inline_template('<%= @watch_full[0,@maxlength.to_i.abs].join(",") %>'), ','),
		default => split(inline_template('<%= @watch_full[[@watch_full.size-@maxlength.to_i.abs,0].max,@maxlength.to_i.abs].join(",") %>'), ','),
	}

	# if the last $settle_count elements are the same, the template
	# should reduce down to the value '1'. check this and the size.
	$one = inline_template('<%= @watch_trim[[@watch_trim.size-@settle_count.to_i,0].max,@settle_count.to_i].uniq.size %>')
	$watch_trim_size = size($watch_trim)
	$settled = ((! $settle_count_check) or ((size($watch_trim) >= $settle_count) and "${one}" == '1'))

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
	$vipif = inline_template("<%= @interfaces.split(',').find_all {|x| '${valid_vip}' == scope.lookupvar('ipaddress_'+x) }[0,1].join('') %>")

	#Gluster::Brick[$valid_bricks] -> Gluster::Volume[$name]	# volume requires bricks

	# get the bricks that match our fqdn, and append /$name to their path.
	# return only these paths, which can be used to build the volume dirs.
	# NOTE: gluster v3.4 won't create a volume if this dir already exists.
	# TODO: is this needed when bricks are devices and not on filesystem ?
	#$volume_dirs = split(inline_template("<%= @valid_bricks.find_all{|x| x.split(':')[0] == '${fqdn}' }.collect {|y| y.split(':')[1].chomp('/')+'/${name}' }.join(' ') %>"), ' ')
	#file { $volume_dirs:
	#	ensure => directory,		# make sure this is a directory
	#	recurse => false,		# don't recurse into directory
	#	purge => false,			# don't purge unmanaged files
	#	force => false,			# don't purge subdirs and links
	#	before => Exec["gluster-volume-create-${name}"],
	#	require => Gluster::Brick[$valid_bricks],
	#}

	# add /${name} to the end of each: brick:/path entry
	$brick_spec = inline_template("<%= @valid_bricks.collect {|x| ''+x.chomp('/')+'/${name}' }.join(' ') %>")

	# if volume creation fails for a stupid reason, in many cases, glusterd
	# already did some of the work and left us with volume name directories
	# on all bricks. the problem is that the future volume create commands,
	# will error if they see that volume directory already present, so when
	# we error we should rmdir any empty volume dirs to keep it pristine...
	# TODO: this should be a gluster bug... we must hope it doesn't happen!
	# maybe related to: https://bugzilla.redhat.com/show_bug.cgi?id=835494
	$rmdir_volume_dirs = sprintf("/bin/rmdir '%s'", inline_template("<%= @valid_bricks.find_all{|x| x.split(':')[0] == '${fqdn}' }.collect {|y| y.split(':')[1].chomp('/')+'/${name}/' }.join('\' \'') %>"))

	# get the list of bricks fqdn's that don't have our fqdn
	$others = inline_template("<%= @valid_bricks.find_all{|x| x.split(':')[0] != '${fqdn}' }.collect {|y| y.split(':')[0] }.join(' ') %>")

	$fping = sprintf("${::gluster::params::program_fping} -q %s", $others)
	$status = sprintf("${::gluster::params::program_gluster} peer status --xml | ${vardir}/xml.py connected %s", $others)

	$onlyif = $ping ? {
		false => "${status}",
		default => [
			"${fping}",
			"${status}",
		],
	}

	$require = $ping ? {
		false => [
			Service["${::gluster::params::service_glusterd}"],
			File["${vardir}/volume/create-${name}.sh"],
			File["${vardir}/xml.py"],	# status check
			Gluster::Brick[$valid_bricks],
			Exec["gluster-volume-stuck-${name}"],
		],
		default => [
			Service["${::gluster::params::service_glusterd}"],
			File["${vardir}/volume/create-${name}.sh"],
			Package["${::gluster::params::package_fping}"],
			File["${vardir}/xml.py"],	# status check
			Gluster::Brick[$valid_bricks],
			Exec["gluster-volume-stuck-${name}"],
		],
	}

	# work around stuck connection state (4) of: 'Accepted peer request'...
	exec { "gluster-volume-stuck-${name}":
		command => "${::gluster::params::misc_gluster_reload}",
		logoutput => on_failure,
		unless => "${::gluster::params::program_gluster} volume list | /bin/grep -qxF '${name}' -",	# reconnect if it doesn't exist
		onlyif => sprintf("${::gluster::params::program_gluster} peer status --xml | ${vardir}/xml.py stuck %s", $others),
		notify => $again ? {
			false => undef,
			default => Common::Again::Delta['gluster-exec-again'],
		},
		require => [
			Service["${::gluster::params::service_glusterd}"],
			File["${vardir}/xml.py"],	# stuck check
			Gluster::Brick[$valid_bricks],
		],
	}

	# store command in a separate file to run as bash...
	# NOTE: we sleep for 5 seconds to give glusterd a chance to
	# settle down first if we're doing a hot (clean) puppet run
	# NOTE: force is needed for now because of the following error:
	# volume create: puppet: failed: The brick annex1.example.com:/var/lib/puppet/tmp/gluster/data/puppet is is being created in the root partition. It is recommended that you don't use the system's root partition for storage backend. Or use 'force' at the end of the command if you want to override this behavior.
	# FIXME: it would be create to have an --allow-root-storage type option
	# instead, so that we don't inadvertently force some other bad thing...
	file { "${vardir}/volume/create-${name}.sh":
		content => inline_template("#!/bin/bash\n/bin/sleep 5s && ${::gluster::params::program_gluster} volume create ${name} ${valid_replica}${valid_stripe}transport ${valid_transport} ${brick_spec} force > >(/usr/bin/tee '/tmp/gluster-volume-create-${name}.stdout') 2> >(/usr/bin/tee '/tmp/gluster-volume-create-${name}.stderr' >&2) || (${rmdir_volume_dirs} && /bin/false)\nexit \$?\n"),
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 755,
		ensure => present,
		# this notify is the first to kick off the 2nd step! it
		# was put here after a process of elimination, and this
		# location makes a lot of sense: on change exec[again]!
		notify => $again ? {
			false => undef,
			default => Common::Again::Delta['gluster-exec-again'],
		},
		require => File["${vardir}/volume/"],
	}

	# run if vip not defined (bypass mode) or if vip exists on this machine
	if ("${valid_vip}" == '' or "${vipif}" != '') {

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
		# TODO: add a timer similar to my puppet-runonce timer code... to wait X minutes after we've settled... useful if we Exec['again'] to speed things up...
		if $settled {
			exec { "gluster-volume-create-${name}":
				command => "${vardir}/volume/create-${name}.sh",
				logoutput => on_failure,
				unless => "${::gluster::params::program_gluster} volume list | /bin/grep -qxF '${name}' -",	# add volume if it doesn't exist
				onlyif => $onlyif,
				#before => TODO?,
				require => $require,
				alias => "gluster-volume-create-${name}",
			}
		}

		if $start == true {
			# try to start volume if stopped
			exec { "${::gluster::params::program_gluster} volume start ${name}":
				logoutput => on_failure,
				onlyif => "${::gluster::params::program_gluster} volume list | /bin/grep -qxF '${name}' -",
				unless => "${::gluster::params::program_gluster} volume status ${name}",	# returns false if stopped
				notify => $shorewall ? {
					false => undef,
					default => $again ? {
						false => undef,
						default => Common::Again::Delta['gluster-exec-again'],
					},
				},
				require => $settled ? {	# require if type exists
					false => undef,
					default => Exec["gluster-volume-create-${name}"],
				},
				alias => "gluster-volume-start-${name}",
			}
		} elsif ( $start == false ) {
			# try to stop volume if running
			# NOTE: this will still succeed even if a client is mounted
			# NOTE: This uses `--mode-script` to workaround the: Stopping volume will
			# make its data inaccessible. Do you want to continue? (y/n)
			# https://access.redhat.com/documentation/en-US/Red_Hat_Storage/2.0/html/Installation_Guide/ch08.html
			exec { "${::gluster::params::program_gluster} --mode=script volume stop ${name}":
				logoutput => on_failure,
				onlyif => "${::gluster::params::program_gluster} volume status ${name}",	# returns true if started
				require => $settled ? {	# require if type exists
					false => Service["${::gluster::params::service_glusterd}"],
					default => Exec["gluster-volume-create-${name}"],
				},
				alias => "gluster-volume-stop-${name}",
			}
		} else {	# 'undef'-ined
			# don't manage volume run state
		}
	}

	if $shorewall {
		$zone = $::gluster::server::zone	# firewall zone

		$ips = $::gluster::server::ips		# override host ip list
		$ip = $::gluster::host::data::ip	# ip of brick's host...
		$source_ips = type3x($ips) ? {
			'array' => inline_template("<%= (@ips+[]).uniq.delete_if {|x| x.empty? }.join(',') %>"),
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
			before => Service["${::gluster::params::service_glusterd}"],
		}

		Gluster::Rulewrapper <<| tag == 'gluster_firewall_volume' and match == "${name}" |>> {
		#Shorewall::Rule <<| tag == 'gluster_firewall_volume' and match == "${name}" |>> {
			source => "${zone}",	# use our source zone
			port => "${port}",	# comma separated string or list
			before => Service["${::gluster::params::service_glusterd}"],
		}
	}

	# fsm variables and boilerplate
	$statefile = "${vardir}/volume/fsm/${name}/state"
	$stackfile = "${vardir}/volume/fsm/${name}/stack"
	$watchfile = "${vardir}/volume/fsm/${name}/watch"
	$diff = "/usr/bin/test '${valid_input}' != '${valid_last}'"
	$stack_truncate = "${maxlength}" ? {
		'-1' => '',	# unlimited
		#default => sprintf("&& /bin/sed -i '%d,$ d' ${stackfile}", inline_template('<%= @maxlength.to_i.abs+1 %>')),
		default => sprintf(" && (/bin/grep -v '^$' ${stackfile} | /usr/bin/tail -n %d | ${vardir}/sponge.py ${stackfile})", inline_template('<%= @maxlength.to_i.abs %>')),
	}
	$watch_truncate = "${maxlength}" ? {
		'-1' => '',	# unlimited
		#default => sprintf("&& /bin/sed -i '%d,$ d' ${watchfile}", inline_template('<%= @maxlength.to_i.abs+1 %>')),
		default => sprintf(" && (/bin/grep -v '^$' ${watchfile} | /usr/bin/tail -n %d | ${vardir}/sponge.py ${watchfile})", inline_template('<%= @maxlength.to_i.abs %>')),
	}

	if $are_bricks_collected and ("${valid_input}" != '') {	# ready or not?

		# TODO: future versions should pickle (but with yaml)
		exec { "/bin/echo '${valid_input}' > '${statefile}'":
			logoutput => on_failure,
			onlyif => "/usr/bin/test ! -e '${statefile}' || ${diff}",
			require => File["${vardir}/volume/fsm/${name}/"],
			alias => "gluster-volume-fsm-state-${name}",
		}

		# NOTE: keep a stack of past transitions, and load them in as a list...
		exec { "/bin/echo '${valid_input}' >> '${stackfile}'${stack_truncate}":
			logoutput => on_failure,
			onlyif => "/usr/bin/test ! -e '${stackfile}' || ${diff}",
			require => [
				File["${vardir}/volume/fsm/${name}/"],
				# easy way to ensure the transition types don't need to
				# add a before to both exec's since this one follows it
				Exec["gluster-volume-fsm-state-${name}"],
			],
			alias => "gluster-volume-fsm-stack-${name}",
		}

		# NOTE: watch *all* transitions, and load them in as a list...
		exec { "/bin/echo '${valid_input}' >> '${watchfile}'${watch_truncate}":
			logoutput => on_failure,
			# we run this if the file doesn't exist, or there is a
			# difference to record, or the sequence hasn't settled
			# we also check that we have our minimum settle count!
			onlyif => "/usr/bin/test ! -e '${watchfile}' || ${diff} || /usr/bin/test '1' != '${one}' || /usr/bin/test ${watch_trim_size} -lt ${settle_count}",
			notify => $again ? {
				false => undef,
				default => Common::Again::Delta['gluster-exec-again'],
			},
			require => [
				File["${vardir}/volume/fsm/${name}/"],
				# easy way to ensure the transition types don't need to
				# add a before to both exec's since this one follows it
				Exec["gluster-volume-fsm-state-${name}"],
			],
			alias => "gluster-volume-fsm-watch-${name}",
		}
	}
}

# vim: ts=8
