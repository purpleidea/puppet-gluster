#Puppet-Gluster

<!--
GlusterFS module by James
Copyright (C) 2010-2013+ James Shubin
Written by James Shubin <james@shubin.ca>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
-->

##A GlusterFS Puppet module by [James](https://ttboj.wordpress.com/)
####Available from:
####[https://github.com/purpleidea/puppet-gluster/](https://github.com/purpleidea/puppet-gluster/)

####Also available from:
####[https://forge.gluster.org/puppet-gluster/](https://forge.gluster.org/puppet-gluster/)

####This documentation is available in: [Markdown](https://github.com/purpleidea/puppet-gluster/blob/master/DOCUMENTATION.md) or [PDF](https://pdfdoc-purpleidea.rhcloud.com/pdf/https://github.com/purpleidea/puppet-gluster/blob/master/DOCUMENTATION.md) format.

####Table of Contents

1. [Overview](#overview)
2. [Module description - What the module does](#module-description)
3. [Setup - Getting started with Puppet-Gluster](#setup)
	* [What can Puppet-Gluster manage?](#what-can-puppet-gluster-manage)
	* [Simple setup](#simple-setup)
	* [Elastic setup](#elastic-setup)
	* [Advanced setup](#advanced-setup)
	* [Client setup](#client-setup)
4. [Usage/FAQ - Notes on management and frequently asked questions](#usage-and-frequently-asked-questions)
5. [Reference - Class and type reference](#reference)
	* [gluster::simple](#glustersimple)
	* [gluster::elastic](#glusterelastic)
	* [gluster::server](#glusterserver)
	* [gluster::host](#glusterhost)
	* [gluster::brick](#glusterbrick)
	* [gluster::volume](#glustervolume)
	* [gluster::volume::property](#glustervolumeproperty)
	* [gluster::mount](#glustermount)
6. [Examples - Example configurations](#examples)
7. [Limitations - Puppet versions, OS compatibility, etc...](#limitations)
8. [Development - Background on module development and reporting bugs](#development)
9. [Author - Author and contact information](#author)

##Overview

The Puppet-Gluster module installs, configures, and manages a GlusterFS cluster.

##Module Description

This Puppet-Gluster module handles installation, configuration, and management
of GlusterFS across all of the hosts in the cluster.

##Setup

###What can Puppet-Gluster manage?

Puppet-Gluster is designed to be able to manage as much or as little of your
GlusterFS cluster as you wish. All features are optional. If there is a feature
that doesn't appear to be optional, and you believe it should be, please let me
know. Having said that, it makes good sense to me to have Puppet-Gluster manage
as much of your GlusterFS infrastructure as it can. At the moment, it cannot
rack new servers, but I am accepting funding to explore this feature ;) At the
moment it can manage:

* GlusterFS packages (rpm)
* GlusterFS configuration files (/var/lib/glusterd/)
* GlusterFS host peering (gluster peer probe)
* GlusterFS storage partitioning (fdisk)
* GlusterFS storage formatting (mkfs)
* GlusterFS brick creation (mkdir)
* GlusterFS services (glusterd)
* GlusterFS firewalling (whitelisting)
* GlusterFS volume creation (gluster volume create)
* GlusterFS volume state (started/stopped)
* GlusterFS volume properties (gluster volume set)
* And much more...

###Simple setup

include '::gluster::simple' is enough to get you up and running. When using the
gluster::simple class, or with any other Puppet-Gluster configuration,
identical definitions must be used on all hosts in the cluster. The simplest
way to accomplish this is with a single shared puppet host definition like:

```puppet
node /^annex\d+$/ {        # annex{1,2,..N}
        class { '::gluster::simple':
        }
}
```

If you wish to pass in different parameters, you can specify them in the class
before you provision your hosts:

```puppet
class { '::gluster::simple':
	replica => 2,
	volume => ['volume1', 'volume2', 'volumeN'],
}
```

###Elastic setup

The gluster::elastic class is not yet available. Stay tuned!

###Advanced setup

Some system administrators may wish to manually itemize each of the required
components for the Puppet-Gluster deployment. This happens automatically with
the higher level modules, but may still be a desirable feature, particularly
for non-elastic storage pools where the configuration isn't expected to change
very often (if ever).

To put together your cluster piece by piece, you must manually include and
define each class and type that you wish to use. If there are certain aspects
that you wish to manage yourself, you can omit them from your configuration.
See the [reference](#reference) section below for the specifics. Here is one
possible example:

```puppet
class { '::gluster::server':
	shorewall => true,
}

gluster::host { 'annex1.example.com':
	# use uuidgen to make these
	uuid => '1f660ca2-2c78-4aa0-8f4d-21608218c69c',
}

# note that this is using a folder on your existing file system...
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
```

###Client setup

Mounting a GlusterFS volume on a client is fairly straightforward. Simply use
the 'gluster::mount' type.

```puppet
	gluster::mount { '/mnt/gluster/puppet/':
		server => 'annex.example.com:/puppet',
		rw => true,
		shorewall => false,
	}
```

In this example, 'annex.example.com' points to the VIP of the GlusterFS
cluster. Using the VIP for mounting increases the chance that you'll get an
available server when you try to mount. This generally works better than RRDNS
or similar schemes.

##Usage and frequently asked questions

All management should be done by manipulating the arguments on the appropriate
Puppet-Gluster classes and types. Since certain manipulations are either not
yet possible with Puppet-Gluster, or are not supported by GlusterFS, attempting
to manipulate the Puppet configuration in an unsupported way will result in
undefined behaviour, and possible even data loss, however this is unlikely.

###How do I change the replica count?

You must set this before volume creation. This is a limitation of GlusterFS.
There are certain situations where you can change the replica count by adding
a multiple of the existing brick count to get this desired effect. These cases
are not yet supported by Puppet-Gluster. If you want to use Puppet-Gluster
before and / or after this transition, you can do so, but you'll have to do the
changes manually.

###Do I need to use a virtual IP?

Using a virtual IP (VIP) is strongly recommended as a distributed lock manager
(DLM) and also to provide a highly-available (HA) IP address for your clients
to connect to. For a more detailed explanation of the reasoning please see:

[How to avoid cluster race conditions or: How to implement a distributed lock manager in puppet](https://ttboj.wordpress.com/2012/08/23/how-to-avoid-cluster-race-conditions-or-how-to-implement-a-distributed-lock-manager-in-puppet/)

Remember that even if you're using a hosted solution (such as AWS) that doesn't
provide an additional IP address, or you want to avoid using an additional IP,
and you're okay not having full HA client mounting, you can use an unused
private RFC1918 IP address as the DLM VIP. Remember that a layer 3 IP can
co-exist on the same layer 2 network with the layer 3 network that is used by
your cluster.

###Is it possible to have Puppet-Gluster complete in a single run?

No. This is a limitation of Puppet, and is related to how GlusterFS operates.
For example, it is not reliably possible to predict which ports a particular
GlusterFS volume will run on until after the volume is started. As a result,
this module will initially whitelist connections from GlusterFS host IP
addresses, and then further restrict this to only allow individual ports once
this information is known. This is possible in conjunction with the
[puppet-shorewall](https://github.com/purpleidea/puppet-shorewall) module.
You should notice that each run should complete without error. If you do see an
error, it means that either something is wrong with your system and / or
configuration, or because there is a bug in Puppet-Gluster.

###Can you integrate this with vagrant?

Yes, see the
[vagrant/](https://github.com/purpleidea/puppet-gluster/tree/master/vagrant)
directory. This has been tested on Fedora 20, with vagrant-libvirt, as I have
no desire to use VirtualBox for fun. I have written an article about this:

[Automatically deploying GlusterFS with Puppet-Gluster + Vagrant!](https://ttboj.wordpress.com/2014/01/08/automatically-deploying-glusterfs-with-puppet-gluster-vagrant/)

You'll probably first need to read my three earlier articles to learn some
vagrant tricks, and to get the needed dependencies installed:

* [Vagrant on Fedora with libvirt](https://ttboj.wordpress.com/2013/12/09/vagrant-on-fedora-with-libvirt/)
* [Vagrant vsftp and other tricks](https://ttboj.wordpress.com/2013/12/21/vagrant-vsftp-and-other-tricks/)
* [Vagrant clustered SSH and ‘screen’](https://ttboj.wordpress.com/2014/01/02/vagrant-clustered-ssh-and-screen/)

###Can I use it without a puppetmaster?

Yes, you can use Puppet-Gluster without a puppetmaster, however you will lose
out on some advantages and features that are simply not possible without one.
The features you will miss out on are Puppet-Gluster features, that make
configuring this module easier, and not any core GlusterFS features.

For example, without a puppetmaster, [gluster::simple](#glustersimple) will not
be able to work, because it relies on the puppetmaster for the exchange of
[exported resources](http://docs.puppetlabs.com/puppet/latest/reference/lang_exported.html)
so that Puppet-Gluster can automatically figure out how many hosts are present
in your cluster.

To use Puppet-Gluster without a puppetmaster, you'll most likely want to use a
configuration that is similar to the [verbose distributed-replicate](https://github.com/purpleidea/puppet-gluster/blob/master/examples/distributed-replicate-example.pp)
example.

The more philosophical way of thinking about this is that if you want to
have multi-hosts coordination of things, so that your life as a sysadmin is
easier, then you'll need to use a puppetmaster so that there is a central
point of coordination. This is a current design limitation of puppet.

Please note that you can still use the [VIP as a DLM](#do-i-need-to-use-a-virtual-ip).

###Puppet runs fail with "Invalid relationship" errors.

When running Puppet, you encounter a compilation failure like:

```bash
Error: Could not retrieve catalog from remote server:
Error 400 on SERVER: Invalid relationship: Exec[gluster-volume-stuck-volname] {
require => Gluster::Brick[annex2.example.com:/var/lib/puppet/tmp/gluster/data/]
}, because Gluster::Brick[annex2.example.com:/var/lib/puppet/tmp/gluster/data/]
doesn't seem to be in the catalog
Warning: Not using cache on failed catalog
Error: Could not retrieve catalog; skipping run
```

This can occur if you have changed (usually removed) the available bricks, but
have not cleared the exported resources on the Puppet master, or if there are
stale (incorrect) brick "tags" on the individual host. These tags can usually
be found in the _/var/lib/puppet/tmp/gluster/brick/_ directory. In other words,
when a multi host cluster comes up, each puppet agent tells the master about
which bricks it has available, and each agent also pulls down this list and
stores it in the brick directory. If there is a discrepancy, then the compile
will fail because the individual host is using old data as part of its facts
when it uses the stale brick data as part of its compilation.

This commonly happens if you're trying to deploy a different Puppet-Gluster
setup without having first erased the host specific exported resources on the
Puppet master or if the machine hasn't been re-provisioned from scratch.

To solve this problem, do a clean install, and make sure that you've cleaned
the Puppet master with:

```bash
puppet node deactivate HOSTNAME
```

for each host you're using, and that you've removed all of the files from the
brick directories on each host.

###Puppet runs fail with "Connection refused - connect(2)" errors.

You may see a "_Connection refused - connect(2)_" message when running puppet.
This typically happens if your puppet vm guest is overloaded. When running high
guest counts on your laptop, or running without hardware virtualization support
this is quite common. Another common causes of this is if your domain type is
set to _qemu_ instead of the accelerated _kvm_. Since the _qemu_ domain type is
much slower, puppet timeouts and failures are common when it doesn't respond.

###Provisioning fails with: "Can't open /dev/sdb1 exclusively."

If when provisioning you get an error like:

_"Can't open /dev/sdb1 exclusively.  Mounted filesystem?"_

It is possible that dracut might have found an existing logical volume on the
device, and device mapper has made it available. This is common if you are
re-using dirty block devices that haven't run through a _dd_ first. Here is an
example of the diagnosis and treatment of this problem:

```bash
[root@server mapper]# pwd
/dev/mapper
[root@server mapper]# dmesg | grep dracut
dracut: dracut-004-336.el6_5.2
dracut: rd_NO_LUKS: removing cryptoluks activation
dracut: Starting plymouth daemon
dracut: rd_NO_DM: removing DM RAID activation
dracut: rd_NO_MD: removing MD RAID activation
dracut: Scanning devices sda3 sdb  for LVM logical volumes myvg/rootvol
dracut: inactive '/dev/vg_foo/lv' [4.35 TiB] inherit
dracut: inactive '/dev/myvg/rootvol' [464.00 GiB] inherit
dracut: Mounted root filesystem /dev/mapper/myvg-rootvol
dracut: Loading SELinux policy
dracut:
dracut: Switching root
[root@server mapper]# /sbin/pvcreate --dataalignment 2560K /dev/sdb1
  Can't open /dev/sdb1 exclusively.  Mounted filesystem?
[root@server mapper]# ls
control  myvg-rootvol  vg_foo-lv
[root@server mapper]# ls -lAh
total 0
crw-rw----. 1 root root 10, 58 Mar  7 16:42 control
lrwxrwxrwx. 1 root root      7 Mar 13 09:56 myvg-rootvol -> ../dm-0
lrwxrwxrwx. 1 root root      7 Mar 13 09:56 vg_foo-lv -> ../dm-1
[root@server mapper]# dmsetup remove vg_foo-lv
[root@server mapper]# ls
control  myvg-rootvol
[root@server mapper]# pvcreate --dataalignment 2560K /dev/sdb1
  Physical volume "/dev/sdb1" successfully created
[root@server mapper]# HAPPY_ADMIN='yes'
```

If you frequently start with "dirty" block devices, you may consider adding a
_dd_ to your hardware provisioning step. The downside is that this can be very
time consuming, and potentially dangerous if you accidentally re-provision the
wrong machine.

###Provisioning fails with: "cannot open /dev/sdb1: Device or resource busy"

If when provisioning you get an error like:

_"mkfs.xfs: cannot open /dev/sdb1: Device or resource busy"_

It is possible that dracut might have found an existing logical volume on the
device, and device mapper has made it available. This is common if you are
re-using dirty block devices that haven't run through a _dd_ first. This is
almost identical to the previous frequently asked question, although this
failure message is what is seen when _mkfs.xfs_ is being blocked by dracut,
where in the former problem it was the _pvcreate_ that was being blocked. The
reason that we see this manifest through _mkfs.xfs_ instead of _pvcreate_ is
that this particular cluster is being build with _lvm => false_. Here is an
example of the diagnosis and treatment of this problem:

```bash
[root@server mapper]# pwd
/dev/mapper
[root@server mapper]# dmesg | grep dracut
dracut: dracut-004-335.el6
dracut: rd_NO_LUKS: removing cryptoluks activation
dracut: Starting plymouth daemon
dracut: rd_NO_DM: removing DM RAID activation
dracut: rd_NO_MD: removing MD RAID activation
dracut: Scanning devices sda2 sdb  for LVM logical volumes vg_server/lv_swap vg_server/lv_root
dracut: inactive '/dev/vg_bricks/b1' [9.00 TiB] inherit
dracut: inactive '/dev/vg_server/lv_root' [50.00 GiB] inherit
dracut: inactive '/dev/vg_server/lv_home' [383.26 GiB] inherit
dracut: inactive '/dev/vg_server/lv_swap' [31.50 GiB] inherit
dracut: Mounted root filesystem /dev/mapper/vg_server-lv_root
dracut:
dracut: Switching root
[root@server mapper]# mkfs.xfs -q -f -i size=512 -n size=8192 /dev/sdb1
mkfs.xfs: cannot open /dev/sdb1: Device or resource busy
[root@server mapper]# lsof /dev/sdb1
[root@server mapper]# echo $?
1
[root@server mapper]# ls
control       vg_server-lv_home  vg_server-lv_swap
vg_bricks-b1  vg_server-lv_root
[root@server mapper]# ls -lAh
total 0
crw-rw---- 1 root root 10, 58 May 20  2014 control
lrwxrwxrwx 1 root root      7 May 20  2014 vg_bricks-b1 -> ../dm-2
lrwxrwxrwx 1 root root      7 May 20  2014 vg_server-lv_home -> ../dm-3
lrwxrwxrwx 1 root root      7 May 20  2014 vg_server-lv_root -> ../dm-0
lrwxrwxrwx 1 root root      7 May 20  2014 vg_server-lv_swap -> ../dm-1
[root@server mapper]# dmsetup remove vg_bricks-b1
[root@server mapper]# ls
control  vg_server-lv_home  vg_server-lv_root  vg_server-lv_swap
[root@server mapper]# mkfs.xfs -q -f -i size=512 -n size=8192 /dev/sdb1
[root@server mapper]# echo $?
0
[root@server mapper]# HAPPY_ADMIN='yes'
```

If you frequently start with "dirty" block devices, you may consider adding a
_dd_ to your hardware provisioning step. The downside is that this can be very
time consuming, and potentially dangerous if you accidentally re-provision the
wrong machine.

###I changed the hardware manually, and now my system won't boot.

If you're using Puppet-Gluster to manage storage, the filesystem will be
mounted with _UUID_ entries in _/etc/fstab_. This ensures that the correct
filesystem will be mounted, even if the device order changes. If a filesystem
is not available at boot time, startup will abort and offer you the chance to
go into read-only maintenance mode. Either fix the hardware issue, or edit the
_/etc/fstab_ file.


###I can't edit /etc/fstab in the maintenance shell because it is read-only.

In the maintenance shell, your root filesystem will be mounted read-only, to
prevent changes. If you need to edit a file such as _/etc/fstab_, you'll first
need to remount the root filesystem in read-write mode. You can do this with:

```bash
mount -n -o remount /
```

###I get a file dependency error when running Puppet-Gluster.

In order for Puppet-Gluster to be able to do its magic, it needs to store some
temporary files on each GlusterFS host. These files usually get stored in:
_/var/lib/puppet/tmp/gluster/_. The parent directory (_/var/lib/puppet/tmp/_)
gets created by the _puppet::vardir_ module. The error you'll typically see is:

```bash
Error: Failed to apply catalog: Could not find dependency
File[/var/lib/puppet/tmp/] for File[/var/lib/puppet/tmp/gluster/] at
/etc/puppet/modules/gluster/manifests/vardir.pp:49
```

This error occurs if you forget to _include_ the _puppet::vardir_ class from
the [puppet-puppet](https://github.com/purpleidea/puppet-puppet/) module. If
you don't want to include the entire module, you can pull in the
_puppet::vardir_ class by itself, or create the contained file type manually in
your puppet manifests.

###I get an undefined method error when running Puppet-Gluster.

This is caused by a regression in a recent version of Puppet. They silently
"removed" a feature, which apparently wasn't supposed to exist, which
Puppet-Gluster relied upon. The original author of Puppet-Gluster would like
this feature added back. If you are affected by this issue, you should see an
an error similar to:

```bash
Error: Could not retrieve catalog from remote server:
Error 400 on SERVER: undefined method `brick_str_to_hash' for
Scope(Gluster::Volume[puppet]):Puppet::Parser::Scope at
/etc/puppet/modules/gluster/manifests/volume.pp:89 on node annex1.example.com
```

Puppet-Gluster now has a patch in git master that works around the missing
feature. This is:

[06af205a562d543bbeb7c4d5c55143ade3bdb4e6](https://github.com/purpleidea/puppet-gluster/commit/06af205a562d543bbeb7c4d5c55143ade3bdb4e6)

Puppet-Gluster has also been
[updated](https://github.com/purpleidea/puppet-gluster/commit/6dfaa8446e4287cf6f7f540158cde700fb95b830)
to fix the issue for users of brick_layout_chained.

###Puppet master gives warning: "Unable to load yaml data/ directory!"

You may see the message "Unable to load yaml data/ directory!" in
_/var/log/messages_ on your puppet master. This error comes from the
_ipa::params_ class. The _ipa::params_ class expects the puppet-module-data
module to read data from the ipa/data directory, and this message indicates
that the module-data module is not installed properly. Most users do not have
this issue, but if you do, here is a workaround:

* Run _puppet config print libdir_ to find the puppet libdir (e.g. /var/lib/puppet/lib).
* Run _mkdir /etc/puppet/modules/module\_data_.
* Copy the contents of the puppet-module-data directory into _/etc/puppet/modules/module\_data_.
* Run "ln -s /etc/puppet/modules/module\_data/lib/hiera _<libdir>_/hiera".
* Restart the puppet master.

###Will this work on my favourite OS? (eg: GNU/Linux F00bar OS v12 ?)
If it's a GNU/Linux based OS, can run GlusterFS, and Puppet, then it will
probably work. Typically, you might need to add a yaml data file to the _data/_
folder so that Puppet-Gluster knows where certain operating system specific
things are found. The multi-distro support has been designed to make it
particularly easy to add support for additional platforms. If your platform
doesn't work, please submit a yaml data file with the platform specific values.

###How do I get the OS independent aspects of this module to work?
The OS independent aspects of this module use the hiera "data-in-modules"
technique. It is actually very simple to get this to work. For a longer write
up of this technique, please read:
[https://ttboj.wordpress.com/2014/06/04/hiera-data-in-modules-and-os-independent-puppet/](https://ttboj.wordpress.com/2014/06/04/hiera-data-in-modules-and-os-independent-puppet/)

In short, this requires puppet version 3.0.0 or greater, and needs the
[module_data](https://github.com/ripienaar/puppet-module-data)
puppet module to be present on the puppet server in the _modules/_ directory.
The *module_data* code should be in a module folder named: *module_data/*.
That's it!

###I just upgraded puppet-gluster and my UUIDs keep resetting to 00000000-0000-0000-0000-000000000000
The following commands `gluster pool list` or `gluster peer status` may also be
failing on some or all of the gluster servers. Furthermore, some hosts may
see other servers, while others are able to list the other peers but they
remain in a disconnected state.

In one case, this was caused by SourceTree's approach to cloning where it was
pulling in all submodules on the Windows OS and/or converting LF (line feed)
to CRLF (carriage return, line feed) compared to how a git clone command pulls
in the repository on a linux OS. In order to resolve this you must delete the
puppet-gluster module directory in its entirety and re-clone it directly on the
target puppet master. If you are using version control to save your puppet
manifests/modules, then please ensure that you perform the appropriate
commmands to save your work and re-push your code with the included changes.

###Awesome work, but it's missing support for a feature and/or platform!

Since this is an Open Source / Free Software project that I also give away for
free (as in beer, free as in gratis, free as in libre), I'm unable to provide
unlimited support. Please consider donating funds, hardware, virtual machines,
and other resources. For specific needs, you could perhaps sponsor a feature!

###You didn't answer my question, or I have a question!

Contact me through my [technical blog](https://ttboj.wordpress.com/contact/)
and I'll do my best to help. If you have a good question, please remind me to
add my answer to this documentation!

##Reference
Please note that there are a number of undocumented options. For more
information on these options, please view the source at:
[https://github.com/purpleidea/puppet-gluster/](https://github.com/purpleidea/puppet-gluster/).
If you feel that a well used option needs documenting here, please contact me.

###Overview of classes and types

* [gluster::simple](#glustersimple): Simple Puppet-Gluster deployment.
* [gluster::elastic](#glusterelastic): Under construction.
* [gluster::server](#glusterserver): Base class for server hosts.
* [gluster::host](#glusterhost): Host type for each participating host.
* [gluster::brick](#glusterbrick): Brick type for each defined brick, per host.
* [gluster::volume](#glustervolume): Volume type for each defined volume.
* [gluster::volume::property](#glustervolumeproperty): Manages properties for each volume.
* [gluster::mount](#glustermount): Client volume mount point management.

###gluster::simple
This is gluster::simple. It should probably take care of 80% of all use cases.
It is particularly useful for deploying quick test clusters. It uses a
finite-state machine (FSM) to decide when the cluster has settled and volume
creation can begin. For more information on the FSM in Puppet-Gluster see:
[https://ttboj.wordpress.com/2013/09/28/finite-state-machines-in-puppet/](https://ttboj.wordpress.com/2013/09/28/finite-state-machines-in-puppet/)

####`replica`
The replica count. Can't be changed automatically after initial deployment.

####`volume`
The volume name or list of volume names to create.

####`path`
The valid brick path for each host. Defaults to local file system. If you need
a different path per host, then Gluster::Simple will not meet your needs.

####`count`
Number of bricks to build per host. This value is used unless _brick_params_ is
being used.

####`vip`
The virtual IP address to be used for the cluster distributed lock manager.
This option can be used in conjunction with the _vrrp_ option, but it does not
require it. If you don't want to provide a virtual ip, but you do want to
enforce that certain operations only run on one host, then you can set this
option to be the ip address of an arbitrary host in your cluster. Keep in mind
that if that host is down, certain options won't ever occur.

####`vrrp`
Whether to automatically deploy and manage _Keepalived_ for use as a _DLM_ and
for use in volume mounting, etc... Using this option requires the _vip_ option.

####`layout`
Which brick layout to use. The available options are: _chained_, and (default).
To generate a default (symmetrical, balanced) layout, leave this option blank.
If you'd like to include an algorithm that generates a different type of brick
layout, it is easy to drop in an algorithm. Please contact me with the details!

####`version`
Which version of GlusterFS do you want to install? This is especially handy
when testing new beta releases. You can read more about the technique at:
[Testing GlusterFS during Glusterfest](https://ttboj.wordpress.com/2014/01/16/testing-glusterfs-during-glusterfest/).

####`repo`
Whether or not to add the necessary software repositories to install the needed
packages. This will typically pull in GlusterFS from _download.gluster.org_ and
should be set to false if you have your own mirrors or repositories managed as
part of your base image.

####`brick_params`
This parameter lets you specify a hash to use when creating the individual
bricks. This is especially useful because it lets you have the power of
Gluster::Simple when managing a cluster of iron (physical machines) where you'd
like to specify brick specific parameters. This sets the brick count when the
_count_ parameter is 0. The format of this parameter might look like:

```bash
$brick_params = {
	fqdn1 => [
		{dev => '/dev/disk/by-uuid/01234567-89ab-cdef-0123-456789abcdef'},
		{dev => '/dev/sdc', partition => false},
	],
	fqdn2 => [{
		dev => '/dev/disk/by-path/pci-0000:02:00.0-scsi-0:1:0:0',
		raid_su => 256, raid_sw => 10,
	}],
	fqdnN => [...],
}
```

####`brick_param_defaults`
This parameter lets you specify a hash of defaults to use when creating each
brick with the _brick_params_ parameter. It is useful because it avoids the
need to repeat the values that are common across all bricks in your cluster.
Since most options work this way, this is an especially nice feature to have.
The format of this parameter might look like:

```bash
$brick_param_defaults = {
	lvm => false,
	xfs_inode64 => true,
	force => true,
}
```

####`brick_params_defaults`
This parameter lets you specify a list of defaults to use when creating each
brick. Each element in the list represents a different brick. The value of each
element is a hash with the actual defaults that you'd like to use for creating
that brick. If you do not specify a brick count by any other method, then the
number of elements in this array will be used as the brick count. This is very
useful if you have consistent device naming across your entire cluster, because
you can very easily specify the devices and brick counts once for all hosts. If
for some reason a particular device requires unique values, then it can be set
manually with the _brick_params_ parameter. Please note the spelling of this
parameter. It is not the same as the _brick_param_defaults_ parameter which is
a global defaults parameter which will apply to all bricks.
The format of this parameter might look like:

```bash
$brick_params_defaults = [
	{'dev' => '/dev/sdb'},
	{'dev' => '/dev/sdc'},
	{'dev' => '/dev/sdd'},
	{'dev' => '/dev/sde'},
]
```

####`setgroup`
Set a volume property group. The two most common or well-known groups are the
_virt_ group, and the _small-file-perf_ group. This functionality is emulated
whether you're using the RHS version of GlusterFS or if you're using the
upstream GlusterFS project, which doesn't (currently) have the _volume set
group_ command. As package managers update the list of available groups or
their properties, Puppet-Gluster will automatically keep your set group
up-to-date. It is easy to extend Puppet-Gluster to add a custom group without
needing to patch the GlusterFS source.

####`ping`
Whether to use _fping_ or not to help with ensuring the required hosts are
available before doing certain types of operations. Optional, but recommended.
Boolean value.

####`again`
Do you want to use _Exec['again']_ ? This helps build your cluster quickly!

####`baseport`
Specify the base port option as used in the glusterd.vol file. This is useful
if the default port range of GlusterFS conflicts with the ports used for
virtual machine migration, or if you simply like to choose the ports that
you're using. Integer value.

####`rpcauthallowinsecure`
This is needed in some setups in the glusterd.vol file, particularly (I think)
for some users of _libgfapi_. Boolean value.

####`shorewall`
Boolean to specify whether puppet-shorewall integration should be used or not.

###gluster::elastic
Under construction.

###gluster::server
Main server class for the cluster. Must be included when building the GlusterFS
cluster manually. Wrapper classes such as [gluster::simple](#glustersimple)
include this automatically.

####`vip`
The virtual IP address to be used for the cluster distributed lock manager.

####`shorewall`
Boolean to specify whether puppet-shorewall integration should be used or not.

###gluster::host
Main host type for the cluster. Each host participating in the GlusterFS
cluster must define this type on itself, and on every other host. As a result,
this is not a singleton like the [gluster::server](#glusterserver) class.

####`ip`
Specify which IP address this host is using. This defaults to the
_$::ipaddress_ variable. Be sure to set this manually if you're declaring this
yourself on each host without using exported resources. If each host thinks the
other hosts should have the same IP address as itself, then Puppet-Gluster and
GlusterFS won't work correctly.

####`uuid`
Universally unique identifier (UUID) for the host. If empty, Puppet-Gluster
will generate this automatically for the host. You can generate your own
manually with _uuidgen_, and set them yourself. I found this particularly
useful for testing, because I would pick easy to recognize UUID's like:
_aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa_,
_bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb_, and so on. If you set a UUID manually,
and Puppet-Gluster has a chance to run, then it will remember your choice, and
store it locally to be used again if you no longer specify the UUID. This is
particularly useful for upgrading an existing un-managed GlusterFS installation
to a Puppet-Gluster managed one, without changing any UUID's.

###gluster::brick
Main brick type for the cluster. Each brick is an individual storage segment to
be used on a host. Each host must have at least one brick to participate in the
cluster, but usually a host will have multiple bricks. A brick can be as simple
as a file system folder, or it can be a separate file system. Please read the
official GlusterFS documentation, if you aren't entirely comfortable with the
concept of a brick.

For most test clusters, and for experimentation, it is easiest to use a
directory on the root file system. You can even use a _/tmp_ sub folder if you
don't care about the persistence of your data. For more serious clusters, you
might want to create separate file systems for your data. On self-hosted iron,
it is not uncommon to create multiple RAID-6 drive pools, and to then create a
separate file system per virtual drive. Each file system can then be used as a
single brick.

So that each volume in GlusterFS has the maximum ability to grow, without
having to partition storage separately, the bricks in Puppet-Gluster are
actually folders (on whatever backing store you wish) which then contain
sub folders-- one for each volume. As a result, all the volumes on a given
GlusterFS cluster can share the total available storage space. If you wish to
limit the storage used by each volume, you can setup quotas. Alternatively, you
can buy more hardware, and elastically grow your GlusterFS volumes, since the
price per GB will be significantly less than any proprietary storage system.
The one downside to this brick sharing, is that if you have chosen the brick
per host count specifically to match your performance requirements, and
each GlusterFS volume on the same cluster has drastically different brick per
host performance requirements, then this won't suit your needs. I doubt that
anyone actually has such requirements, but if you do insist on needing this
compartmentalization, then you can probably use the Puppet-Gluster grouping
feature to accomplish this goal. Please let me know about your use-case, and
be warned that the grouping feature hasn't been extensively tested.

To prove to you that I care about automation, this type offers the ability to
automatically partition and format your file systems. This means you can plug
in new iron, boot, provision and configure the entire system automatically.
Regrettably, I don't have a lot of test hardware to routinely use this feature.
If you'd like to donate some, I'd be happy to test this thoroughly. Having said
that, I have used this feature, I consider it to be extremely safe, and it has
never caused me to lose data. If you're uncertain, feel free to look at the
code, or avoid using this feature entirely. If you think there's a way to make
it even safer, then feel free to let me know.

####`dev`
Block device, such as _/dev/sdc_ or _/dev/disk/by-id/scsi-0123456789abcdef_. By
default, Puppet-Gluster will assume you're using a folder to store the brick
data, if you don't specify this parameter.

####`raid_su`
Get this information from your RAID device. This is used to do automatic
calculations for alignment, so that the:

```
	dev -> part -> lvm -> fs
```

stack is aligned properly. Future work is possible to manage your RAID devices,
and to read these values automatically. Specify this value as an integer number
of kilobytes (k).

####`raid_sw`
Get this information from your RAID device. This is used to do automatic
calculations for alignment, so that the:

```
	dev -> part -> lvm -> fs
```

stack is aligned properly. Future work is possible to manage your RAID devices,
and to read these values automatically. Specify this value as an integer.

####`partition`
Do you want to partition the device and build the next layer on that partition,
or do you want to build on the block device directly? The "next layer" will
typically be lvm if you're using lvm, or your file system (such as xfs) if
you're skipping the lvm layer.

####`labeltype`
Only _gpt_ is supported. Other options include _msdos_, but this has never been
used because of it's size limitations.

####`lvm`
Do you want to use lvm on the lower level device (typically a partition, or the
device itself), or not. Using lvm might be required when using a commercially
supported GlusterFS solution.

####`lvm_thinp`
Set to _true_ to enable LVM thin provisioning. Read 'man 7 lvmthin' to
understand what thin provisioning is all about. This is needed for one form of
GlusterFS snapshots. Obviously this requires that you also enable _LVM_.

####`lvm_virtsize`
The value that will be passed to _--virtualsize_. By default this will pass in
a command that will return the size of your volume group. This is usually a
sane value, and help you to remember not to overcommit.

####`lvm_chunksize`
Value of _--chunksize_ for _lvcreate_ when using thin provisioning.

####`lvm_metadatasize`
Value of _--poolmetadatasize_ for _lvcreate_ when using thin provisioning.

####`fsuuid`
File system UUID. This ensures we can distinctly identify a file system. You
can set this to be used with automatic file system creation, or you can specify
the file system UUID that you'd like to use. If you leave this blank, then
Puppet-Gluster can automatically pick an fs UUID for you. This is especially
useful if you are automatically deploying a large cluster on physical iron.

####`fstype`
This should be _xfs_ or _ext4_. Using _xfs_ is recommended, but _ext4_ is also
quite common. This only affects a file system that is getting created by this
module. If you provision a new machine, with a root file system of _ext4_, and
the brick you create is a root file system path, then this option does nothing.
A _btrfs_ option is now available for testing. It is not officially supported
by GlusterFS, but testing it anyways, and reporting any issues is encouraged.

####`xfs_inode64`
Set _inode64_ mount option when using the _xfs_ fstype. Choose _true_ to set.

####`xfs_nobarrier`
Set _nobarrier_ mount option when using the _xfs_ fstype. Choose _true_ to set.

####`ro`
Whether the file system should be mounted read only. For emergencies only.

####`force`
If _true_, this will overwrite any xfs file system it sees. This is useful for
rebuilding GlusterFS repeatedly and wiping data. There are other safeties in
place to stop this. In general, you probably don't ever want to touch this.

####`areyousure`
Do you want to allow Puppet-Gluster to do dangerous things? You have to set
this to _true_ to allow Puppet-Gluster to _fdisk_ and _mkfs_ your file system.

####`again`
Do you want to use _Exec['again']_ ? This helps build your cluster quickly!

####`comment`
Add any comment you want. This is also occasionally used internally to do magic
things.

###gluster::volume
Main volume type for the cluster. This is where a lot of the magic happens.
Remember that changing some of these parameters after the volume has been
created won't work, and you'll experience undefined behaviour. There could be
FSM based error checking to verify that no changes occur, but it has been left
out so that this code base can eventually support such changes, and so that the
user can manually change a parameter if they know that it is safe to do so.

####`bricks`
List of bricks to use for this volume. If this is left at the default value of
_true_, then this list is built automatically. The algorithm that determines
this order does not support all possible situations, and most likely can't
handle certain corner cases. It is possible to examine the FSM to view the
selected brick order before it has a chance to create the volume. The volume
creation script won't run until there is a stable brick list as seen by the FSM
running on the host that has the DLM. If you specify this list of bricks
manually, you must choose the order to match your desired volume layout. If you
aren't sure about how to order the bricks, you should review the GlusterFS
documentation first.

####`transport`
Only _tcp_ is supported. Possible values can include _rdma_, but this won't get
any testing if I don't have access to infiniband hardware. Donations welcome.

####`replica`
Replica count. Usually you'll want to set this to _2_. Some users choose _3_.
Other values are seldom seen. A value of _1_ can be used for simply testing a
distributed setup, when you don't care about your data or high availability. A
value greater than _4_ is probably wasteful and unnecessary. It might even
cause performance issues if a synchronous write is waiting on a slow fourth
server.

####`stripe`
Stripe count. Thoroughly unsupported and untested option. Not recommended for
use by GlusterFS.

####`layout`
Which brick layout to use. The available options are: _chained_, and (default).
To generate a default (symmetrical, balanced) layout, leave this option blank.
If you'd like to include an algorithm that generates a different type of brick
layout, it is easy to drop in an algorithm. Please contact me with the details!

####`ping`
Do we want to include ping checks with _fping_?

####`settle`
Do we want to run settle checks?

####`again`
Do you want to use _Exec['again']_ ? This helps build your cluster quickly!

####`start`
Requested state for the volume. Valid values include: _true_ (start), _false_
(stop), or _undef_ (un-managed start/stop state).

###gluster::volume::property
Main volume property type for the cluster. This allows you to manage GlusterFS
volume specific properties. There are a wide range of properties that volumes
support. For the full list of properties, you should consult the GlusterFS
documentation, or run the _gluster volume set help_ command. To set a property
you must use the special name pattern of: _volume_#_key_. The value argument is
used to set the associated value. It is smart enough to accept values in the
most logical format for that specific property. Some properties aren't yet
supported, so please report any problems you have with this functionality.
Because this feature is an awesome way to _document as code_ the volume
specific optimizations that you've made, make sure you use this feature even if
you don't use all the others.

####`value`
The value to be used for this volume property.

###gluster::mount
Main type to use to mount GlusterFS volumes. This type offers special features,
like shorewall integration, and repo support.

####`server`
Server specification to use when mounting. Format is _<server>:/volume_. You
may use an _FQDN_ or an _IP address_ to specify the server.

####`rw`
Mount read-write or read-only. Defaults to read-only. Specify _true_ for
read-write.

####`mounted`
Mounted argument from standard mount type. Defaults to _true_ (_mounted_).

####`repo`
Boolean to select if you want automatic repository (package) management or not.

####`version`
Specify which GlusterFS version you'd like to use.

####`ip`
IP address of this client. This is usually auto-detected, but you can choose
your own value manually in case there are multiple options available.

####`shorewall`
Boolean to specify whether puppet-shorewall integration should be used or not.

##Examples
For example configurations, please consult the [examples/](https://github.com/purpleidea/puppet-gluster/tree/master/examples) directory in the git
source repository. It is available from:

[https://github.com/purpleidea/puppet-gluster/tree/master/examples](https://github.com/purpleidea/puppet-gluster/tree/master/examples)

It is also available from:

[https://forge.gluster.org/puppet-gluster/puppet-gluster/trees/master/examples](https://forge.gluster.org/puppet-gluster/puppet-gluster/trees/master/examples/)

##Limitations

This module has been tested against open source Puppet 3.2.4 and higher.

The module is routinely tested on:

* CentOS 6.5

It will probably work without incident or without major modification on:

* CentOS 5.x/6.x
* RHEL 5.x/6.x

It has patches to support:

* Fedora 20+
* Ubuntu 12.04+
* Debian 7+

It will most likely work with other Puppet versions and on other platforms, but
testing on those platforms has been minimal due to lack of time and resources.

Testing is community supported! Please report any issues as there are a lot of
features, and in particular, support for additional distros isn't well tested.
The multi-distro architecture has been chosen to easily support new additions.
Most platforms and versions will only require a change to the yaml based data/
folder.

##Development

This is my personal project that I work on in my free time.
Donations of funding, hardware, virtual machines, and other resources are
appreciated. Please contact me if you'd like to sponsor a feature, invite me to
talk/teach or for consulting.

You can follow along [on my technical blog](https://ttboj.wordpress.com/).

To report any bugs, please file a ticket at: [https://bugzilla.redhat.com/enter_bug.cgi?product=GlusterFS&component=puppet-gluster](https://bugzilla.redhat.com/enter_bug.cgi?product=GlusterFS&component=puppet-gluster).

##Author

Copyright (C) 2010-2013+ James Shubin

* [github](https://github.com/purpleidea/)
* [&#64;purpleidea](https://twitter.com/#!/purpleidea)
* [https://ttboj.wordpress.com/](https://ttboj.wordpress.com/)

