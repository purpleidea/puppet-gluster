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
	$vip = ''		# strongly recommended
) {
	include gluster::vardir

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	if "${path}" == '' {
		file { "${vardir}/data/":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => false,		# don't purge unmanaged files
			force => false,		# don't purge subdirs and links
			require => File["${vardir}/"],
		}
	}

	$chosen_path = "${path}" ? {
		'' => "${vardir}/data/",
		default => "${path}",
	}

	$valid_path = sprintf("%s/", regsubst($chosen_path, '\/$', ''))

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
		#zone => 'net',	# defaults to net
		shorewall => true,
	}

	@@gluster::host { "${::fqdn}":
	}
	Gluster::Host <<||>>

	@@gluster::brick { "${::fqdn}:${valid_path}":
		areyousure => true,
	}

	Gluster::Brick <<||>>

	gluster::volume { $volume:
		replica => $replica,
		stripe => $stripe,
		# NOTE: with this method you do not choose the order of course!
		# the gluster_fqdns fact is alphabetical, but not complete till
		# at least a puppet run of each node has occured. watch out for
		# partial clusters missing some of the nodes with bad ordering!
		#bricks => split(inline_template("<%= gluster_fqdns.split(',').collect {|x| x+':${valid_path}' }.join(',') %>"), ','),
		# the only semi-safe way is the new built in automatic collect:
		bricks => true,			# automatic brick collection...
		start => true,
	}
	Gluster::Volume <<||>>
}

# vim: ts=8
