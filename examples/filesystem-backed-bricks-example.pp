#
#	example of a simple replicate with 2 hosts, and filesystem path bricks
#	NOTE: this should be put on *every* gluster host
#

class gluster_base {

	class { '::gluster::server':
		ips => ['192.168.123.101', '192.168.123.102'],
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

	$brick_list = [
		'annex1.example.com:/data/gluster-storage1',
		'annex2.example.com:/data/gluster-storage2',
	]

	gluster::volume { 'examplevol':
		replica => 2,
		bricks => $brick_list,
		start => undef,	# i'll start this myself
	}

	# namevar must be: <VOLNAME>#<KEY>
	gluster::volume::property { 'examplevol#auth.reject':
		value => ['192.0.2.13', '198.51.100.42', '203.0.113.69'],
	}
}

