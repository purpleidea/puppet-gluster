#
#	simple gluster setup. yeah, that's it.
#	this should run on *every* gluster host
#	NOTE: this should use a VIP.
#

node /^annex\d+$/ {	# annex{1,2,..N}

	# NOTE: this class offers some configuration, see the source for info.
	# NOTE: this is mostly intended for fast gluster testing. for more
	# complex setups, you might want to look at the other examples.
	class { '::gluster::simple':
		setgroup => 'virt',	# or: 'small-file-perf', or others too!
	}

}

