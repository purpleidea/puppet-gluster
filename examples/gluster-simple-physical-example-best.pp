#
#	really simple gluster setup for physical provisioning.
#	(yeah, that's it-- for iron!)
#

node /^annex\d+$/ {	# annex{1,2,..N}

	class { '::gluster::simple':
		replica => 2,
		vip => '192.168.1.42',
		vrrp => true,
		# NOTE: _each_ host will have four bricks with these devices...
		brick_params_defaults => [	# note the spelling and type...
			{'dev' => '/dev/sdb'},
			{'dev' => '/dev/sdc'},
			{'dev' => '/dev/sdd'},
			{'dev' => '/dev/sde'},
		],
		brick_param_defaults => {	# every brick will use these...
			lvm => false,
			xfs_inode64 => true,
			force => true,
		},
		#brick_params => {},	# NOTE: you can also use this option to
		# override a particular fqdn with the options that you need to!
	}
}

