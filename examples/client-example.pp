# gluster::client example
# This is the recommended way of mounting puppet-gluster.
# NOTE: It makes sense to use the VIP as the server to mount from, since it
# stays HA if one of the other nodes goes down.

# mount a share on one of the gluster hosts (note the added require)
$annex_loc_vip_1 = '172.16.1.80'
gluster::client { '/mnt/gshared':
	server => "${annex_loc_vip_1}:/gshared",
	rw => true,
	mounted => true,
	require => Gluster::Volume['gshared'],	# TODO: too bad this can't ensure it's started
}

# mount a share on a client somewhere
gluster::client { '/mnt/some_mount_point':
	server => "${annex_loc_vip_1}:/some_volume_name",
	rw => true,
	mounted => true,
}

