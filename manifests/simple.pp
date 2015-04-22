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

class gluster::simple(
	$path = '',
	$volume = 'puppet',	# NOTE: this can be a list...
	$replica = 1,
	$stripe = 1,		# TODO: not fully implemented in puppet-gluster
	$layout = '',		# brick layout to use (default, chained, etc...)
	$vip = '',		# strongly recommended
	$vrrp = false,
	$password = '',	# global vrrp password to use
	$version = '',
	$repo = true,
	$count = 0,	# 0 means build 1 brick, unless $brick_params exists...
	$brick_params = {},	# this sets the brick count when $count is 0...
	$brick_param_defaults = {},	# these always get used to build bricks
	$brick_params_defaults = [],	# array of hashes to use as brick count
	$setgroup = '',		# pick a volume property group to set, eg: virt
	$ping = true,	# use fping or not?
	$again = true,	# do we want to use Exec['again'] ?
	$baseport = '',	# specify base port option as used in glusterd.vol file
	$rpcauthallowinsecure = false,	# needed in some setups in glusterd.vol
	$shorewall = true
) {
	include gluster::vardir
	include gluster::volume::property::group::data	# make the groups early

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	# NOTE: this is done in brick.pp now
	#if "${path}" == '' {
	#	file { "${vardir}/data/":
	#		ensure => directory,	# make sure this is a directory
	#		recurse => false,	# don't recurse into directory
	#		purge => false,		# don't purge unmanaged files
	#		force => false,		# don't purge subdirs and links
	#		require => File["${vardir}/"],
	#	}
	#}

	$chosen_path = "${path}" ? {
		'' => "${vardir}/data/",
		default => "${path}",
	}

	$valid_path = sprintf("%s/", regsubst($chosen_path, '\/$', ''))

	# Stdlib 4.6.0 deprecates 'type' in favor of 'type3x'.
	# Ensure $valid_volumes is always an array.
	$valid_volumes = type3x($volume) ? {
		'array' => $volume,
		default => ["${volume}"],
	}

	# if this is a hash, then it's used as the defaults for all the bricks!
	validate_hash($brick_param_defaults)
	# if someone explicitly added this value, then don't overwrite it...
	$areyousure = {'areyousure' => true}
	$againhash = {'again' => $again}	# pass through the $again value
	$valid_brick_param_defaults = merge($areyousure, $againhash, $brick_param_defaults)

	# if this is an array, then each element is the default for each brick!
	# if this is an array, then the number of elements is the brick count!!
	validate_array($brick_params_defaults)
	# TODO: check that each element of array is a valid hash!
	$valid_brick_params_defaults = $brick_params_defaults

	notify { 'gluster::simple':
		message => 'You are using gluster::simple !',
	}

	if "${vip}" == '' {
		# If you don't use a VIP, things will be racy, but could mostly
		# work. If you run puppet manually, then a vip isn't necessary.
		# see: http://ttboj.wordpress.com/2012/08/23/how-to-avoid-cluster-race-conditions-or-how-to-implement-a-distributed-lock-manager-in-puppet/
		warning('It is highly recommended to use a VIP.')
	}

	class { '::gluster::server':
		vip => "${vip}",
		vrrp => $vrrp,
		password => "${password}",
		version => "${version}",
		repo => $repo,
		baseport => $baseport,
		rpcauthallowinsecure => $rpcauthallowinsecure,
		#zone => 'net',	# defaults to net
		shorewall => $shorewall,
	}

	if "${::fqdn}" == '' {
		fail('Your $fqdn is empty. Please check your DNS settings.')
	}

	@@gluster::host { "${::fqdn}":
	}
	Gluster::Host <<||>>

	# the idea here is to build a list of bricks from a list of parameters,
	# with each element in the list, corresponding to a hash of key=>values
	# each element in the list is a different brick. the key for the master
	# hash is the fqdn of the host that those bricks correspond to. you can
	# also specify a list of defaults for when you have common brick values
	# such as $xfs_inode64=>true, or raid_* if your cluster is symmetrical!
	# if you set the $count variable, then that brick count will be forced.
	validate_re("${count}", '^\d+$')	# ensure this is a positive int

	# here some wizardry happens...
	if has_key($brick_params, "${::fqdn}") {
		$brick_params_list = $brick_params["${::fqdn}"]
	} else {
		$brick_params_list = []
	}

	$brick_params_list_length = inline_template('<%= @brick_params_list.length %>')
	$brick_params_defaults_length = inline_template('<%= @valid_brick_params_defaults.length %>')
	$valid_count = "${count}" ? {
		'0' => "${brick_params_list_length}" ? {
			'0' => "${brick_params_defaults_length}" ? {
				'0' => 1,	# 0 means undefined, so use the default
				default => "${brick_params_defaults_length}",
			},
			default => "${brick_params_list_length}",
		},
		default => $count,
	}

	$brick_params_names = "${valid_count}" ? {
		# TODO: should we use the same pattern for 1 or many ?
		'1' => ["${::fqdn}:${valid_path}"],
		default => split(inline_template("<%= (1..@valid_count.to_i).collect{|i| '${::fqdn}:${valid_path}brick' + i.to_s.rjust(7, '0') + '/' }.join(',') %>"), ','),
	}

	validate_array($brick_params_list)

	# NOTE: I've kept this template split as two comment chunks for
	# readability. Puppet needs to fix this issue somehow! Creating
	# a separate template removes the logic from the code, but as a
	# large inline template it's very hard to read/write the logic!
	#DEFAULTS = (((i < @valid_brick_params_defaults.length) and @valid_brick_params_defaults[i].is_a?(Hash)) ? @valid_brick_params_defaults[i] : {})
	#$yaml = inline_template("<%= (0..@valid_count.to_i-1).inject(Hash.new) { |h,i| {@brick_params_names[i] => DEFAULTS.merge((i < @brick_params_list.length) ? @brick_params_list[i] : {})}.merge(h) }.to_yaml %>")
	$yaml = inline_template("<%= (0..@valid_count.to_i-1).inject(Hash.new) { |h,i| {@brick_params_names[i] => (((i < @valid_brick_params_defaults.length) and @valid_brick_params_defaults[i].is_a?(Hash)) ? @valid_brick_params_defaults[i] : {}).merge((i < @brick_params_list.length) ? @brick_params_list[i] : {})}.merge(h) }.to_yaml %>")
	$hash = parseyaml($yaml)
	create_resources('@@gluster::brick', $hash, $valid_brick_param_defaults)
	#@@gluster::brick { "${::fqdn}:${valid_path}":
	#	areyousure => true,
	#}
	Gluster::Brick <<||>>

	gluster::volume { $valid_volumes:
		replica => $replica,
		stripe => $stripe,
		layout => "${layout}",
		# NOTE: with this method you do not choose the order of course!
		# the gluster_fqdns fact is alphabetical, but not complete till
		# at least a puppet run of each node has occured. watch out for
		# partial clusters missing some of the nodes with bad ordering!
		#bricks => split(inline_template("<%= @gluster_fqdns.split(',').collect {|x| x+':${valid_path}' }.join(',') %>"), ','),
		# the only semi-safe way is the new built in automatic collect:
		bricks => true,			# automatic brick collection...
		ping => $ping,
		start => true,
		again => $again,
	}
	Gluster::Volume <<||>>

	# set a group of volume properties
	if "${setgroup}" != '' {
		$setgroup_yaml = inline_template("<%= @valid_volumes.inject(Hash.new) { |h,i| {i+'#'+@setgroup => {}}.merge(h) }.to_yaml %>")
		$setgroup_hash = parseyaml($setgroup_yaml)
		$setgroup_defaults = {'vip' => "${vip}"}
		create_resources('gluster::volume::property::group', $setgroup_hash, $setgroup_defaults)
	}
}

# vim: ts=8
