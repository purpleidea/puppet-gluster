#
#	simple gluster setup for physical provisioning.
#	(yeah, that's it-- for iron!)
#

node /^annex\d+$/ {	# annex{1,2,..N}

	class { '::gluster::simple':
		# by allowing you to enumerate these things here in this class,
		# you're able to specify all of these from a provisioning tool.
		# this is useful in a tool like foreman which only lets you set
		# class variables, and doesn't let you define individual types!
		replica => 2,
		vip = '192.168.1.42',
		vrrp = true,
		# NOTE: this example will show you different possibilities, but
		# it is probably not sane to define your devices in a mixed way
		brick_params => {
			'fqdn1.example.com' => [
				{dev => '/dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef'},
				{dev => '/dev/sde', partition => false},
			],
			'fqdn2.example.com' => [
				{dev => '/dev/disk/by-path/pci-0000:02:00.0-scsi-0:1:0:0', raid_su => 256, raid_sw => 10}
				{dev => '/dev/disk/by-id/wwn-0x600508e0000000002b012b744715743a', lvm => true},
			],
			#'fqdnN.example.com' => [...],
		},

		# these will get used by every brick, even if only specified by
		# the count variable... keep in mind that without the $dev var,
		# some of these parameters aren't used by the filesystem brick.
		brick_param_defaults => {
			lvm => false,
			xfs_inode64 => true,
			force => true,
		},
	}
}

