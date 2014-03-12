node default {
	# this will get put on every host...
	$url = 'https://ttboj.wordpress.com/'
	file { '/etc/motd':
		content => "This is Puppet-Gluster+Vagrant! (${url})\n",
	}
}

# puppetmaster
node puppet inherits default {

	if "${::vagrant_gluster_firewall}" != 'false' {
		include firewall
	}

	$allow = split("${::vagrant_gluster_allow}", ',')	# ip list fact

	class { '::puppet::server':
		pluginsync => true,	# do we want to enable pluginsync?
		storeconfigs => true,	# do we want to enable storeconfigs?
		autosign => [
			'*',		# FIXME: this is a temporary solution
			#"*.${domain}",	# FIXME: this is a temporary solution
		],
		#allow_duplicate_certs => true,	# redeploy without cert clean
		allow => $allow,	# also used in fileserver.conf
		repo => true,		# automatic repos
		shorewall => "${::vagrant_gluster_firewall}" ? {
			'false' => false,
			default => true,
		},
		start => true,
	}

	class { '::puppet::deploy':
		path => '/vagrant/puppet/',	# puppet folder is put here...
		backup => false,		# don't use puppet to backup...
	}
}

node /^annex\d+$/ inherits default {	# annex{1,2,..N}

	if "${::vagrant_gluster_firewall}" != 'false' {
		include firewall
	}

	class { '::puppet::client':
		#start => true,
		start => false,			# useful for testing manually...
	}

	# this is a simple way to setup gluster
	class { '::gluster::simple':
		volume => 'puppet',
		replica => "${::vagrant_gluster_replica}",
		count => "${::vagrant_gluster_bricks}",	# brick count
		layout => "${::vagrant_gluster_layout}",
		vip => "${::vagrant_gluster_vip}",	# from vagrant
		version => "${::vagrant_gluster_version}",
		vrrp => true,
		setgroup => "${::vagrant_gluster_setgroup}",
		shorewall => "${::vagrant_gluster_firewall}" ? {
			'false' => false,
			default => true,
		},
	}
}

node /^client\d+$/ inherits default {	# client{1,2,..N}

	if "${::vagrant_gluster_firewall}" != 'false' {
		include firewall
	}

	class { '::puppet::client':
		#start => true,
		start => false,	# useful for testing manually...
	}

	$host = "${::vagrant_gluster_vip_fqdn}" ? {
		'' => "${::vagrant_gluster_vip}",
		default => "${::vagrant_gluster_vip_fqdn}",
	}

	gluster::mount { '/mnt/gluster/puppet/':
		server => "${host}:/puppet",
		rw => true,
		version => "${::vagrant_gluster_version}",
		shorewall => "${::vagrant_gluster_firewall}" ? {
			'false' => false,
			default => true,
		},
	}
}

class firewall {

	$FW = '$FW'			# make using $FW in shorewall easier

	class { '::shorewall::configuration':
		# NOTE: no configuration specifics are needed at the moment
	}

	shorewall::zone { ['net', 'man']:
		type => 'ipv4',
		options => [],	# these aren't really needed right now
	}

	# management zone interface used by vagrant-libvirt
	shorewall::interface { 'man':
		interface => 'MAN_IF',
		broadcast => 'detect',
		physical => 'eth0',	# XXX: set manually!
		options => ['dhcp', 'tcpflags', 'routefilter', 'nosmurfs', 'logmartians'],
		comment => 'Management zone.',	# FIXME: verify options
	}

	# XXX: eth1 'dummy' zone to trick vagrant-libvirt into leaving me alone
	# <no interface definition needed>

	# net zone that gluster uses to communicate
	shorewall::interface { 'net':
		interface => 'NET_IF',
		broadcast => 'detect',
		physical => 'eth2',	# XXX: set manually!
		options => ['tcpflags', 'routefilter', 'nosmurfs', 'logmartians'],
		comment => 'Public internet zone.',	# FIXME: verify options
	}

	# TODO: is this policy really what we want ? can we try to limit this ?
	shorewall::policy { '$FW-net':
		policy => 'ACCEPT',		# TODO: shouldn't we whitelist?
	}

	shorewall::policy { '$FW-man':
		policy => 'ACCEPT',		# TODO: shouldn't we whitelist?
	}

	####################################################################
	#ACTION      SOURCE DEST                PROTO DEST  SOURCE  ORIGINAL
	#                                             PORT  PORT(S) DEST
	shorewall::rule { 'ssh': rule => "
	SSH/ACCEPT   net    $FW
	SSH/ACCEPT   man    $FW
	", comment => 'Allow SSH'}

	shorewall::rule { 'ping': rule => "
	#Ping/DROP    net    $FW
	Ping/ACCEPT  net    $FW
	Ping/ACCEPT  man    $FW
	", comment => 'Allow ping from the `bad` net zone'}

	shorewall::rule { 'icmp': rule => "
	ACCEPT       $FW    net                 icmp
	ACCEPT       $FW    man                 icmp
	", comment => 'Allow icmp from the firewall zone'}
}

