#
#	example of a simple replicate with 2 hosts and 1 arbiter,
#	and filesystem path bricks
#	NOTE: this should be put on *every* gluster host
#
#
#	layout:
#
#		annex1.example.com (192.168.123.101) = regular node
#		annex2.example.com (192.168.123.102) = regular node
#		annex3.example.com (192.168.123.103) = arbiter
#
#	NOTE: An arbiter is always the last brick in the variable
#	$brick_list which is passed to volume::gluster define
#


class gluster_base {

	$ips = [
		'192.168.123.101',
		'192.168.123.102',
		'192.168.123.103',
	]

	class { '::gluster::server':
		ips => $ips,
		shorewall => true,
	}

	gluster::host { 'annex1.example.com':
		# use uuidgen to make these
		uuid => '1f660ca2-2c78-4aa0-8f4d-21608218c69c',
	}

	# note that this is using a folder on your existing filesystem...
	# this can be useful for prototyping gluster using virtual machines
	# if this isn't a separate partition, remember that your root fs will
	# run out of space when your gluster volume does!
	gluster::brick { 'annex1.example.com:/data/gluster-storage1':
		areyousure => true,
	}

	gluster::host { 'annex2.example.com':
		# NOTE: specifying a host uuid is now optional!
		# if you don't choose one, one will be assigned
		#uuid => '2fbe6e2f-f6bc-4c2d-a301-62fa90c459f8',
	}

	gluster::brick { 'annex2.example.com:/data/gluster-storage2':
		areyousure => true,
	}

	gluster::host { 'annex3.example.com':
		# NOTE: specifying a host uuid is now optional!
		# if you don't choose one, one will be assigned
		#uuid => '512f9f6c-8be8-489c-995b-9826e27e6146',
	}

	gluster::brick { 'annex3.example.com:/data/gluster-storage3':
		# NOTE: this is the brick on the arbiter, files and
		# directories will be created in the same way as on
		# regular node but they will be empty
		areyousure => true,
	}

	# NOTE: The last brick from the $brick_list will be used
	# as an arbiter. This order is crucial for Gluster.
	$brick_list = [
		'annex1.example.com:/data/gluster-storage1',
		'annex2.example.com:/data/gluster-storage2',
		'annex3.example.com:/data/gluster-storage3',	# arbiter
	]

	gluster::volume { 'examplevol':
		replica => 3,
		arbiter => 1,
		bricks => $brick_list,
		start => undef,	# i'll start this myself
	}

	# namevar must be: <VOLNAME>#<KEY>
	gluster::volume::property { 'examplevol#auth.reject':
		value => ['192.0.2.13', '198.51.100.42', '203.0.113.69'],
	}
}
