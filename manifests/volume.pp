# Simple? gluster module by James
# Copyright (C) 2010-2012  James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

define gluster::volume(
  $bricks = [],
  $transport = 'tcp',
  $replica = 1,
  $stripe = 1,
  $start = undef			# start volume ? true, false (stop it) or undef
) {
  # TODO: if using rdma, maybe we should pull in the rdma package... ?
  $valid_transport = $transport ? {
    'rdma' => 'rdma',
    'tcp,rdma' => 'tcp,rdma',
    default => 'tcp',
  }

  $valid_replica = $replica ? {
    '1' => '',
    default => "replica ${replica} ",
  }

  $valid_stripe = $stripe ? {
    '1' => '',
    default => "stripe ${stripe} ",
  }

  #Gluster::Brick[$bricks] -> Gluster::Volume[$name]	# volume requires bricks

  # get the bricks that match our fqdn, and append /$name to their path.
  # return only these paths, which can be used to build the volume dirs.
  $volume_dirs = split(inline_template("<%= bricks.find_all{|x| x.split(':')[0] == '${fqdn}' }.collect {|y| y.split(':')[1].chomp('/')+'/${name}' }.join(' ') %>"), ' ')

  file { $volume_dirs:
    ensure => directory,		# make sure this is a directory
    recurse => false,			# don't recurse into directory
    purge => false,			# don't purge unmanaged files
    force => false,			# don't purge subdirs and links
    before => Exec["gluster-volume-create-${name}"],
    require => Gluster::Brick[$bricks],
  }

  # add /${name} to the end of each: brick:/path entry
  $brick_spec = inline_template("<%= bricks.collect {|x| ''+x.chomp('/')+'/${name}' }.join(' ') %>")

  # EXAMPLE: gluster volume create test replica 2 transport tcp annex1.example.com:/storage1a/test annex2.example.com:/storage2a/test annex3.example.com:/storage3b/test annex4.example.com:/storage4b/test annex1.example.com:/storage1c/test annex2.example.com:/storage2c/test annex3.example.com:/storage3d/test annex4.example.com:/storage4d/test
  # NOTE: this should only happen on one host
  # FIXME: there might be a theoretical race condition if this runs at
  # exactly the same time time on more than one host.
  # FIXME: this should probably fail on at least N-1 nodes before it
  # succeeds because it probably shouldn't work until all the bricks are
  # available, which per node will happen right before this runs.
  exec { "/usr/sbin/gluster volume create ${name} ${valid_replica}${valid_stripe}transport ${valid_transport} ${brick_spec}":
    logoutput => on_failure,
    unless => "/usr/sbin/gluster volume list | /bin/grep -qxF '${name}' -",	# add volume if it doesn't exist
    #before => TODO?,
    #require => Gluster::Brick[$bricks],
    alias => "gluster-volume-create-${name}",
  }

  # TODO:
  #if $shorewall {
  #  shorewall::rule { 'gluster-TODO':
  #    rule => "
  #    ACCEPT        ${zone}    $FW        tcp    24009:${endport}
  #    ",
  #    comment => 'TODO',
  #    before => Service['glusterd'],
  #  }
  #}

  if $start == true {
    # try to start volume if stopped
    exec { "/usr/sbin/gluster volume start ${name}":
      logoutput => on_failure,
      unless => "/usr/sbin/gluster volume status ${name}",	# returns false if stopped
      require => Exec["gluster-volume-create-${name}"],
      alias => "gluster-volume-start-${name}",
    }
  } elsif ( $start == false ) {
    # try to stop volume if running
    # NOTE: this will still succeed even if a client is mounted
    # NOTE: This uses `yes` to workaround the: Stopping volume will
    # make its data inaccessible. Do you want to continue? (y/n)
    # TODO: http://community.gluster.org/q/how-can-i-make-automatic-scripts/
    # TODO: gluster --mode=script volume stop ...
    exec { "/usr/bin/yes | /usr/sbin/gluster volume stop ${name}":
      logoutput => on_failure,
      onlyif => "/usr/sbin/gluster volume status ${name}",	# returns true if started
      require => Exec["gluster-volume-create-${name}"],
      alias => "gluster-volume-stop-${name}",
    }
  } else {
    # don't manage volume run state
  }
}

