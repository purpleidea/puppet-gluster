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

	# build a list of hashes with ordered vdX devices
	# (s='';q=i;(q, r = (q - 1).divmod(26)) && s.prepend(('a'..'z').to_a[r]) until q.zero?;'/dev/vd'+s)
	$skip = 1	# skip over 1 disk (eg: /dev/vda from the host)
	$disks = "${::vagrant_gluster_disks}"
	$disks_yaml = inline_template("<%= (1+@skip.to_i..@disks.to_i+@skip.to_i).collect { |i| { 'dev' => (s='';q=i;(q, r = (q - 1).divmod(26)) && s.insert(0, ('a'..'z').to_a[r]) until q.zero?;'/dev/vd'+s) } }.to_yaml %>")
	#$brick_params_defaults = [	# this is one possible example data set
	#	{'dev' => '/dev/vdb'},
	#	{'dev' => '/dev/vdc'},
	#	{'dev' => '/dev/vdd'},
	#	{'dev' => '/dev/vde'},
	#]
	$brick_params_defaults = parseyaml($disks_yaml)
	notice(inline_template('disks: <%= YAML::load(@disks_yaml).inspect %>'))
	#notify { 'disks':
	#	message => inline_template('disks: <%= YAML::load(@disks_yaml).inspect %>'),
	#}

	$brick_param_defaults = {
		# TODO: set these from vagrant variables...
		'lvm' => false,
		'fstype' => "${::vagrant_gluster_fstype}" ? {
			'' => undef,
			default => "${::vagrant_gluster_fstype}",
		},
		'xfs_inode64' => true,
		'force' => true,
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
		# NOTE: this is brick_params_defaults NOT param! param is below
		brick_params_defaults => "${::vagrant_gluster_disks}" ? {
			'0' => undef,
			# NOTE: _each_ host will have N bricks with these devs!
			default => $brick_params_defaults,
		},
		brick_param_defaults => "${::vagrant_gluster_disks}" ? {
			'0' => undef,
			# NOTE: _each_ brick will use these...
			default => $brick_param_defaults,
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

