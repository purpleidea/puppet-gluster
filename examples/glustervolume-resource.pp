# This class handles all calls to the gluster module.
# As you notice the calls are very limited as the partitioning is handled in de node section.

class gluster {

  class {
    gluster::server:
      hosts => ['gluster1',
                'gluster2']
  }

  gluster::host { 
    # use uuidgen to make these
    'gluster1': uuid => '81efbca2-50d2-11e2-a3dd-c76dc7c87da4';
    'gluster2': uuid => '8cec1650-50d2-11e2-9f5e-7b9148ea10a8';
  }

  gluster_volume {
    'testvolume':
      ensure  => present,
      replica => 2,
      bricks  => ['gluster1:/gluster/brick1', 'gluster2:/gluster/brick2'],
  }

}


node 'gluster1' {

  include nfs::client
  include gluster

  # Prepare the filesystem for Gluster
  package {
    'xfsprogs': ensure => installed;
  }

  logical_volume {
    'gluster_brick1':
      ensure       => present,
      volume_group => 'systemvg',
      size         => '45G';
  }

  filesystem {
    '/dev/systemvg/gluster_brick1':
      ensure  => present,
      fs_type => 'xfs',
      require => [Logical_volume['gluster_brick1'],Package['xfsprogs']];
  }

  file {
    '/gluster':         ensure => directory;
    '/gluster/brick1':  ensure => directory;
  }

  mount {
    '/gluster/brick1':
      ensure  => mounted,
      fstype  => 'xfs',
      options => 'defaults',
      device  => '/dev/systemvg/gluster_brick1',
      require => [Filesystem['/dev/systemvg/gluster_brick1'],File['/gluster/brick1']],
      before  => Class['gluster'];
  }

  mount {
    '/var/lib/libvirt/images':
      ensure   => mounted,
      device   => 'localhost:/testvolume',
      fstype   => 'nfs',
      options  => 'vers=3,_netdev',
      remounts => false,
      atboot   => true,
      require  => [Service['glusterd_online'],Class['gluster','kvm']];
  }

}

node 'gluster2' {

  include nfs::client
  include gluster

  # Prepare the filesystem for Gluster
  package {
    'xfsprogs': ensure => installed;
  }

  logical_volume {
    'gluster_brick2':
      ensure       => present,
      volume_group => 'systemvg',
      size         => '45G';
  }

  filesystem {
    '/dev/systemvg/gluster_brick2':
      ensure  => present,
      fs_type => 'xfs',
      require => [Logical_volume['gluster_brick2'],Package['xfsprogs']];
  }

  file { 
    '/gluster':         ensure => directory; 
    '/gluster/brick2':  ensure => directory; 
  }

  mount {
    '/gluster/brick2':
      ensure  => mounted,
      fstype  => 'xfs',
      options => 'defaults',
      device  => '/dev/systemvg/gluster_brick2',
      require => [Filesystem['/dev/systemvg/gluster_brick2'],File['/gluster/brick2']],
      before  => Class['gluster'];
  }

  mount {
    '/var/lib/libvirt/images':
      ensure   => mounted,
      device   => 'localhost:/testvolume',
      fstype   => 'nfs',
      options  => 'vers=3,_netdev',
      remounts => false,
      atboot   => true,
      require  => [Service['glusterd_online'],Class['gluster','kvm']];
  }

}
