# gluster::mount example using puppet-nfs and puppet-ipa to serve up your data!
# NOTE: you'll need to consult puppet-ipa/examples/ to setup the freeipa server

# mount a share on your nfs server, at the moment that nfs server is a SPOF :-(
$gvip = '203.0.113.42'
gluster::mount { '/export/homes':
	server => "${gvip}:/homes",
	rw => true,
	mounted => true,
	require => Gluster::Volume['homes'],	# TODO: too bad this can't ensure it's started
}

class { '::nfs::server':
	domain => "${::domain}",
	ipa => 'nfs',			# the ipa::client::service name
	kerberos => 'ipa',		# optional when we're using ipa
	shorewall => true,
}

# the $name here is the client mountpoint when we use: safety => false!
nfs::server::export { '/homes/':	# name is the client mountpoint
	export => '/export/homes/',
	rw => true,
	async => false,
	wdelay => true,		# if false then async must be false too
	rootsquash => true,
	sec => true,		# set true for automatic kerberos magic
	options => [],		# add any other options you might want!
	hosts => ["ws*.${domain}"],	# export to these hosts only...
	exported => true,	# create exported resources for clients
	tagas => 'homes',
	safety => false,	# be super clever (see the module docs)
	comment => 'Export home directories for ws*',
	require => Gluster::Mount['/export/homes/'],
}

# and here is how you can collect / mount ~automatically on the client:
class { '::nfs::client':
	kerberos => true,
}

nfs::client::mount::collect { 'homes':	# match the $tagas from export!
	server => "${::hostname}.${::domain}",
	#suid => false,
	#clientaddr => "${::ipaddress}",	# use this if you want!
}

