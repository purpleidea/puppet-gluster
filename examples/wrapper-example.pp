# gluster::wrapper example
# This is the recommended way of using puppet-gluster.
# NOTE: I have broken down the trees into pieces to make them easier to read.
# You can do it exactly like this, use giant trees, or even generate the tree
# using your favourite puppet tool.
# NOTE: These tree objects are actually just nested ruby hashes.

class { 'gluster::wrapper':
	nodetree => $nodetree,
	volumetree => $volumetree,
	# NOTE: this is the virtual ip as managed by keepalived. At this time,
	# you must set up this part on your own. Using the VIP is recommended.
	# NOTE: you can set this to any of the node ip's to manage puppet from
	# a single master, or you can leave it blank to get the nodes to race.
	vip => '172.16.1.80',
}

$brick1a = {
	dev => '/dev/disk/by-id/scsi-36003048007e26c00173ad3b633a2ef67',	# /dev/sda
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '1ae49642-7f34-4886-8d23-685d13867fb1',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick1c = {
	dev => '/dev/disk/by-id/scsi-36003048007e26c00173ad3b633a36700',	# /dev/sdb
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '1c9ee010-9cd1-4d81-9a73-f0788d5b3e33',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick2a = {
	dev => '/dev/disk/by-id/scsi-36003048007df450014ca27ee19eaec55',	# /dev/sdc
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '2affe5e3-c10d-4d42-a887-cf8993a6c7b5',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick2c = {
	dev => '/dev/disk/by-id/scsi-36003048007df450014ca280e1bda8e70',	# /dev/sdd
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '2c434d6c-7800-4eec-9121-483bee2336f6',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick3b = {
	dev => '/dev/disk/by-id/scsi-36003048007e14f0014ca2722130bc87c',	# /dev/sdc
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '3b79d76b-a519-493c-9f21-ca35524187ef',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick3d = {
	dev => '/dev/disk/by-id/scsi-36003048007e14f0014ca2743150a5471',	# /dev/sdd
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '3d125f8a-c3c3-490d-a606-453401e9bc21',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick4b = {
	dev => '/dev/disk/by-id/scsi-36003048007e36700174029270d81faa1',	# /dev/sdc
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '4bf21ae6-06a0-44ad-ab48-ea23417e4e44',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$brick4d = {
	dev => '/dev/disk/by-id/scsi-36003048007e36700174029270d82724d',	# /dev/sdd
	labeltype => 'gpt',
	fstype => 'xfs',
	fsuuid => '4dfa7e50-2315-44d3-909b-8e9423def6e5',
	xfs_inode64 => true,
	xfs_nobarrier => true,
	areyousure => true,
}

$nodetree = {
	'annex1.example.com' => {
		'ip' => '172.16.1.81',
		'uuid' => '1f660ca2-2c78-4aa0-8f4d-21608218c69c',
		'bricks' => {
			'/mnt/storage1a' => $brick1a,
			'/mnt/storage1c' => $brick1c,
		},
	},
	'annex2.example.com' => {
		'ip' => '172.16.1.82',
		'uuid' => '2fbe6e2f-f6bc-4c2d-a301-62fa90c459f8',
		'bricks' => {
			'/mnt/storage2a' => $brick2a,
			'/mnt/storage2c' => $brick2c,
		},
	},
	'annex3.example.com' => {
		'ip' => '172.16.1.83',
		'uuid' => '3f5a86fd-6956-46ca-bb80-65278dc5b945',
		'bricks' => {
			'/mnt/storage3b' => $brick3b,
			'/mnt/storage3d' => $brick3d,
		},
	},
	'annex4.example.com' => {
		'ip' => '172.16.1.84',
		'uuid' => '4f8e3157-e1e3-4f13-b9a8-51e933d53915',
		'bricks' => {
			'/mnt/storage4b' => $brick4b,
			'/mnt/storage4d' => $brick4d,
		},
	}
}

$volumetree = {
	'examplevol1' => {
		'transport' => 'tcp',
		'replica' => 2,
		'clients' => ['172.16.1.143'],	# for the auth.allow and $FW
		# NOTE: if you *don't* specify a bricks argument, the full list
		# of bricks above will be used for your new volume. This is the
		# usual thing that you want to do. Alternatively you can choose
		# your own bricks[] if you're doing something special or weird!
		#'bricks' => [],
	},

	'examplevol2' => {
		'transport' => 'tcp',
		'replica' => 2,
		'clients' => ['172.16.1.143', '172.16.1.253'],
		#'bricks' => [],
	}
}

