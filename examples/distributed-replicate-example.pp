#
#	example of a distributed-replicate with four hosts, and two bricks each
#	NOTE: this should be put on *every* gluster host
#
#$annex_loc_vip_1 = '172.16.1.80'	# vip
$annex_loc_ip_1 = '172.16.1.81'
$annex_loc_ip_2 = '172.16.1.82'
$annex_loc_ip_3 = '172.16.1.83'
$annex_loc_ip_4 = '172.16.1.84'

$some_client_ip = ''

class gluster_base {

	class { 'gluster::server':
		hosts => ['annex1.example.com', 'annex2.example.com', 'annex3.example.com', 'annex4.example.com'],
		ips => ["${annex_loc_ip_1}", "${annex_loc_ip_2}", "${annex_loc_ip_3}", "${annex_loc_ip_4}"],
		#vip => "${annex_loc_vip_1}",
		clients => [$some_client_ip],
		zone => 'loc',
		shorewall => true,
	}

	gluster::host { 'annex1.example.com':
		# use uuidgen to make these
		uuid => '1f660ca2-2c78-4aa0-8f4d-21608218c69c',
	}

	gluster::brick { 'annex1.example.com:/mnt/storage1a':
		dev => '/dev/disk/by-id/scsi-36003048007e26c00173ad3b633a2ef67',	# /dev/sda
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '1ae49642-7f34-4886-8d23-685d13867fb1',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::brick { 'annex1.example.com:/mnt/storage1c':
		dev => '/dev/disk/by-id/scsi-36003048007e26c00173ad3b633a36700',	# /dev/sdb
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '1c9ee010-9cd1-4d81-9a73-f0788d5b3e33',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::host { 'annex2.example.com':
		uuid => '2fbe6e2f-f6bc-4c2d-a301-62fa90c459f8',
	}

	gluster::brick { 'annex2.example.com:/mnt/storage2a':
		dev => '/dev/disk/by-id/scsi-36003048007df450014ca27ee19eaec55',	# /dev/sdc
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '2affe5e3-c10d-4d42-a887-cf8993a6c7b5',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::brick { 'annex2.example.com:/mnt/storage2c':
		dev => '/dev/disk/by-id/scsi-36003048007df450014ca280e1bda8e70',	# /dev/sdd
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '2c434d6c-7800-4eec-9121-483bee2336f6',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::host { 'annex3.example.com':
		uuid => '3f5a86fd-6956-46ca-bb80-65278dc5b945',
	}

	gluster::brick { 'annex3.example.com:/mnt/storage3b':
		dev => '/dev/disk/by-id/scsi-36003048007e14f0014ca2722130bc87c',	# /dev/sdc
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '3b79d76b-a519-493c-9f21-ca35524187ef',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::brick { 'annex3.example.com:/mnt/storage3d':
		dev => '/dev/disk/by-id/scsi-36003048007e14f0014ca2743150a5471',	# /dev/sdd
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '3d125f8a-c3c3-490d-a606-453401e9bc21',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::host { 'annex4.example.com':
		uuid => '4f8e3157-e1e3-4f13-b9a8-51e933d53915',
	}

	gluster::brick { 'annex4.example.com:/mnt/storage4b':
		dev => '/dev/disk/by-id/scsi-36003048007e36700174029270d81faa1',	# /dev/sdc
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '4bf21ae6-06a0-44ad-ab48-ea23417e4e44',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	gluster::brick { 'annex4.example.com:/mnt/storage4d':
		dev => '/dev/disk/by-id/scsi-36003048007e36700174029270d82724d',	# /dev/sdd
		labeltype => 'gpt',
		fstype => 'xfs',
		fsuuid => '4dfa7e50-2315-44d3-909b-8e9423def6e5',
		xfs_inode64 => true,
		xfs_nobarrier => true,
		areyousure => true,
	}

	$brick_list = [
		'annex1.example.com:/mnt/storage1a',
		'annex2.example.com:/mnt/storage2a',
		'annex3.example.com:/mnt/storage3b',
		'annex4.example.com:/mnt/storage4b',
		'annex1.example.com:/mnt/storage1c',
		'annex2.example.com:/mnt/storage2c',
		'annex3.example.com:/mnt/storage3d',
		'annex4.example.com:/mnt/storage4d',
	]

	# TODO: have this run transactionally on *one* gluster host.
	gluster::volume { 'examplevol':
		replica => 2,
		bricks => $brick_list,
		start => undef,	# i'll start this myself
	}

	# namevar must be: <VOLNAME>#<KEY>
	gluster::volume::property { 'examplevol#auth.reject':
		value => '192.0.2.13,198.51.100.42,203.0.113.69',
	}

	#gluster::volume::property { 'examplevol#cluster.data-self-heal-algorithm':
	#	value => 'full',
	#}

	#gluster::volume { 'someothervol':
	#	replica => 2,
	#	bricks => $brick_list,
	#	start => undef,
	#}

}
