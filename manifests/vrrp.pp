class gluster::vrrpdir {

  include gluster::vardir

  $vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

  file { "${vardir}/vrrp/":
    ensure => directory,	# make sure this is a directory
    recurse => true,	# recurse into directory
#    purge => true,		# purge unmanaged files
    force => true,		# purge subdirs and links
    require => File["${vardir}/"],
  }
}
