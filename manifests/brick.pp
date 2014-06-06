# GlusterFS module by James
# Copyright (C) 2010-2013+ James Shubin
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

define gluster::brick(
	$group = 'default',		# grouping for multiple puppet-glusters
	# if dev is false, path in $name is used directly after a mkdir -p
	$dev = false,			# /dev/sdc, /dev/disk/by-id/scsi-36003048007e14f0014ca2743150a5471

	$raid_su = '',			# used by mkfs.xfs and lvm, eg: 256 (K)
	$raid_sw = '',			# used by mkfs.xfs and lvm, eg: 10

	$partition = true,		# partition, or build on the block dev?
	$labeltype = '',		# gpt

	$lvm = true,			# use lvm or not ?
	$lvm_thinp = false,		# use lvm thin-p or not ?
	$lvm_virtsize = '',		# defaults to 100% available.
	$lvm_chunksize = '',		# chunk size for thin-p
	$lvm_metadatasize = '',		# meta data size for thin-p

	$fsuuid = '',			# set a uuid for this fs (uuidgen)
	$fstype = '',			# xfs
	$ro = false,			# use for emergencies only- you want your fs rw

	$xfs_inode64 = false,
	$xfs_nobarrier = false,
	$force = false,			# if true, this will overwrite any xfs fs it sees, useful for rebuilding gluster and wiping data. NOTE: there are other safeties in place to stop this.
	$areyousure = false,		# do you allow puppet to do dangerous things ?
	$again = true,			# do we want to use Exec['again'] ?
	$comment = ''
) {
	include gluster::brick::base
	if $again {
		include gluster::again
	}
	include gluster::vardir
	include gluster::params

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	# eg: annex1.example.com:/storage1a
	$split = split($name, ':')	# do some $name parsing
	$host = $split[0]		# host fqdn
	# NOTE: technically $path should be everything BUT split[0]. This
	# lets our $path include colons if for some reason they're needed.
	#$path = $split[1]		# brick mount or storage path
	# TODO: create substring function
	$path = inline_template("<%= '${name}'.slice('${host}'.length+1, '${name}'.length-'${host}'.length-1) %>")
	$short_path = sprintf("%s", regsubst($path, '\/$', ''))	# no trailing
	$valid_path = sprintf("%s/", regsubst($path, '\/$', ''))

	if ! ( "${host}:${path}" == "${name}" ) {
		fail('The brick $name must match a $host-$path pattern.')
	}

	Gluster::Host[$host] -> Gluster::Brick[$name]	# brick requires host

	# create a brick tag to be collected by the gluster_brick_group_* fact!
	$safename = regsubst("${name}", '/', '_', 'G')	# make /'s safe
	file { "${vardir}/brick/${safename}.${group}":
		content => "${name}\n",
		owner => "${::gluster::params::misc_owner_root}",
		group => "${::gluster::params::misc_group_root}",
		mode => 644,
		ensure => present,
		require => File["${vardir}/brick/"],
	}

	#
	#	fsuuid...
	#
	if ("${fsuuid}" != '') and (! ("${fsuuid}" =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/)) {
		fail("The chosen fs uuid: '${fsuuid}' is not valid.")
	}

	# if we manually *pick* a uuid, then store it too, so that it
	# sticks if we ever go back to using automatic uuids. this is
	# useful if a user wants to initially import uuids by picking
	# them manually, and then letting puppet take over afterwards
	if "${fsuuid}" != '' {
		# $group is unnecessary, but i left it in for consistency...
		file { "${vardir}/brick/fsuuid/${safename}.${group}":
			content => "${fsuuid}\n",
			owner => "${::gluster::params::misc_owner_root}",
			group => "${::gluster::params::misc_group_root}",
			mode => 600,	# might as well...
			ensure => present,
			require => File["${vardir}/brick/fsuuid/"],
		}
	}

	# we sha1 to prevent weird characters in facter
	$fsuuid_safename = sha1("${name}.${group}")
	$valid_fsuuid = "${fsuuid}" ? {
		# fact from the data generated in: ${vardir}/brick/fsuuid/*
		'' => getvar("gluster_brick_fsuuid_${fsuuid_safename}"),	# fact!
		default => "${fsuuid}",
	}

	# you might see this on first run if the fsuuid isn't generated yet
	if (type($dev) != 'boolean') and ("${valid_fsuuid}" == '') {
		warning('An $fsuuid must be specified or generated.')
	}

	#
	#	raid...
	#
	# TODO: check inputs for sanity and auto-detect if one is empty
	# TODO: maybe we can detect these altogether from the raid set!
	if "${raid_su}" == '' and "${raid_sw}" == '' {
		# if we are not using a real device, we should ignore warnings!
		if type($dev) != 'boolean' {			# real devices!
			if $lvm or "${fstype}" == 'xfs' {
				warning('Setting $raid_su and $raid_sw is recommended.')
			}
		}
	} elsif "${raid_su}" != '' and "${raid_sw}" != '' {
		# ensure both are positive int's !
		validate_re("${raid_su}", '^\d+$')
		validate_re("${raid_sw}", '^\d+$')

	} else {
		fail('You must set both $raid_su and $raid_sw or neither.')
	}

	#
	#	partitioning...
	#
	$valid_labeltype = $labeltype ? {
		#'msdos' => 'msdos',	# TODO
		default => 'gpt',
	}

	# get the raw /dev/vdx device, and append the partition number
	$dev0 = "`/bin/readlink -e ${dev}`"	# resolve to /dev/<device>

	$part_mklabel = "${::gluster::params::program_parted} -s -m -a optimal ${dev0} mklabel ${valid_labeltype}"
	$part_mkpart = "${::gluster::params::program_parted} -s -m -a optimal ${dev0} mkpart primary 0% 100%"

	#
	$dev1 = $partition ? {
		false => "${dev0}",	# block device without partition
		default => "${dev0}1",	# partition one (eg: /dev/sda1)
	}

	#
	#	lvm...
	#
	if $lvm_thinp and ( ! $lvm ) {
		warning('You must enable $lvm if you want to use LVM thin-p.')
	}

	if $lvm {
		# NOTE: this is used for thin-provisioning, and RHS compliance!

		# NOTE: as a consequence of this type of automation, we generate
		# really ugly vg names like: "vg_annex1.example.com+_gluster_" !
		# TODO: in the future, it might be nice to provide an option to
		# use simplified naming based on hostname and a brick number...
		$lvm_safename = regsubst("${safename}", ':', '+', 'G')	# safe!
		$lvm_vgname = "vg_${lvm_safename}"
		$lvm_lvname = "lv_${lvm_safename}"
		$lvm_tpname = "tp_${lvm_safename}"	# thin pool (tp)

		$lvm_dataalignment = inline_template('<%= @raid_su.to_i*@raid_sw.to_i %>')

		$lvm_pvcreate = "${raid_su}${raid_sw}" ? {	# both empty ?
			'' => "${::gluster::params::program_pvcreate} ${dev1}",
			default => "${::gluster::params::program_pvcreate} --dataalignment ${lvm_dataalignment}K ${dev1}",
		}

		$lvm_vgcreate = "${::gluster::params::program_vgcreate} ${lvm_vgname} ${dev1}"

		# match --virtualsize with 100% of available vg by default
		$lvm_thinp_virtsize = "${lvm_virtsize}" ? {	# --virtualsize
			'' => "`${::gluster::params::program_vgs} -o size --units b --noheadings ${lvm_vgname}`",
			default => "${lvm_virtsize}",
		}

		# TODO: is 64k a good/sane default ?
		$lvm_thinp_chunksize = "${lvm_chunksize}" ? {
			'' => '',
			default => "--chunksize ${lvm_chunksize}",
		}

		# TODO: is 16384 a good/sane default ?
		$lvm_thinp_metadatasize = "${lvm_metadatasize}" ? {
			'' => '',
			default => "--poolmetadatasize ${lvm_metadatasize}",
		}

		# README: 'man 7 lvmthin' to understand lvm thin provisioning
		# MIRROR: http://man7.org/linux/man-pages/man7/lvmthin.7.html
		# TODO: is this the optimal setup for thin-p ?
		$lvm_thinp_lvcreate_cmdlist = [
			"${::gluster::params::program_lvcreate}",
			"--thinpool ${lvm_vgname}/${lvm_tpname}",	# thinp
			'--extents 100%FREE',	# let lvm figure out the --size
			"--virtualsize ${lvm_thinp_virtsize}",
			"${lvm_thinp_chunksize}",
			"${lvm_thinp_metadatasize}",
			" -n ${lvm_lvname}",	# name it
		]
		$lvm_thinp_lvcreate = join(delete($lvm_thinp_lvcreate_cmdlist, ''), ' ')

		# creates dev /dev/vgname/lvname
		$lvm_lvcreate = $lvm_thinp ? {
			true => "${lvm_thinp_lvcreate}",
			default => "${::gluster::params::program_lvcreate} --extents 100%PVS -n ${lvm_lvname} ${lvm_vgname}",
		}
	}

	$dev2 = $lvm ? {
		false => "${dev1}",	# pass through, because not using lvm
		default => "/dev/${lvm_vgname}/${lvm_lvname}",	# thin-p too :)
	}

	#
	#	mkfs...
	#
	$ro_bool = $ro ? {		# this has been added as a convenience
		true => 'ro',
		default => 'rw',
	}

	# if $dev is false, we assume we're using a path backing store on brick
	$valid_fstype = type($dev) ? {
		'boolean' => $dev ? {
			false => 'path',	# no dev, just a path spec
			default => '',		# invalid type
		},
		default => $fstype ? {
			'ext4' => 'ext4',	# TODO
			'btrfs' => 'btrfs',
			default => 'xfs',
		},
	}

	if ( $valid_fstype == 'path' ) {

		# do a mkdir -p in the execution section below...
		$options_list = []	# n/a

	# XFS mount options:
	# http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=blob;f=Documentation/filesystems/xfs.txt;hb=HEAD
	} elsif ( $valid_fstype == 'xfs' ) {
		# exec requires
		include gluster::brick::xfs
		$exec_requires = [Package["${::gluster::params::package_xfsprogs}"]]

		$xfs_arg00 = "${::gluster::params::program_mkfs_xfs}"

		$xfs_arg01 = '-q'	# shh!

		# NOTE: the -f forces creation when it sees an old xfs part
		$xfs_arg02 = $force ? {
			true => '-f',
			default => '',
		}

		# Due to extensive use of extended attributes, RHS recommends
		# XFS inode size set to 512 bytes from the defaults 256 Bytes.
		$xfs_arg03 = '-i size=512'

		# An XFS file system allows you to select a logical block size
		# for the file-system directory that is greater than the
		# logical block size of the file-system. Increasing the logical
		# block size for the directories from the default of 4K,
		# decreases the directory IO, which improves the performance of
		# directory operations. See:
		# http://xfs.org/index.php/XFS_FAQ#Q:_Performance:_mkfs.xfs_-n_size.3D64k_option
		$xfs_arg04 = '-n size=8192'

		# To align the IO at the file system layer it is important that
		# we set the correct stripe unit (stripe element size) and
		# stripe width (number of data disks) while formatting the file
		# system. These options are sometimes auto-detected but manual
		# configuration is needed with many of the hardware RAID
		# volumes.
		$xfs_arg05 = "${raid_su}${raid_sw}" ? {	# both empty ?
			'' => '',
			default => "-d su=${raid_su}k,sw=${raid_sw}",
		}

		$xfs_cmdlist = [
			"${xfs_arg00}",
			"${xfs_arg01}",
			"${xfs_arg02}",
			"${xfs_arg03}",
			"${xfs_arg04}",
			"${xfs_arg05}",
			"${dev2}"
		]
		$xfs_cmd = join(delete($xfs_cmdlist, ''), ' ')

		# TODO: xfs_admin doesn't have a --quiet flag. silence it...
		$xfs_admin = "${::gluster::params::program_xfsadmin} -U '${valid_fsuuid}' ${dev2}"

		# mkfs w/ uuid command
		$mkfs_exec = "${xfs_cmd} && ${xfs_admin}"

		# By default, XFS allocates inodes to reflect their on-disk
		# location. However, because some 32-bit userspace applications
		# are not compatible with inode numbers greater than 232, XFS
		# will allocate all inodes in disk locations which result in
		# 32-bit inode numbers. This can lead to decreased performance
		# on very large filesystems (i.e. larger than 2 terabytes),
		# because inodes are skewed to the beginning of the block
		# device, while data is skewed towards the end.
		# To address this, use the inode64 mount option. This option
		# configures XFS to allocate inodes and data across the entire
		# file system, which can improve performance.
		$option01 = $xfs_inode64 ? {
			true => 'inode64',
			default => '',
		}

		# By default, XFS uses write barriers to ensure file system
		# integrity even when power is lost to a device with write
		# caches enabled. For devices without write caches, or with
		# battery-backed write caches, disable barriers using the
		# nobarrier option.
		$option02 = $xfs_nobarrier ? {
			true => 'nobarrier',
			default => '',
		}

		$options_list = ["${option01}", "${option02}","${::gluster::params::misc_mount_nofail}"]

	} elsif ( $valid_fstype == 'ext4' ) {
		# exec requires
		include gluster::brick::ext4
		$exec_requires = [Package["${::gluster::params::package_e2fsprogs}"]]

		# mkfs w/ uuid command
		$mkfs_exec = "${::gluster::params::program_mkfs_ext4} -U '${valid_fsuuid}' ${dev2}"

		# mount options
		$options_list = ["${::gluster::params::misc_mount_nofail}"]	# TODO

	} elsif ( $valid_fstype == 'btrfs' ) {
		# exec requires
		include gluster::brick::btrfs
		$exec_requires = [Package["${::gluster::params::package_btrfsprogs}"]]

		# FIXME: this filesystem has not yet been optimized for performance

		# mkfs w/ uuid command
		$mkfs_exec = "${::gluster::params::program_mkfs_btrfs} -U '${valid_fsuuid}' ${dev2}"

		# mount options
		$options_list = ["${::gluster::params::misc_mount_nofail}"]	# TODO

	} else {
		fail('The $fstype is invalid.')
	}

	# put all the options in an array, remove the empty ones, and join with
	# commas (this removes ',,' double comma uglyness)
	# adding 'defaults' here ensures no ',' (leading comma) in mount command
	$mount_options = inline_template('<%= (["defaults"]+@options_list).delete_if {|x| x.empty? }.join(",") %>')

	$exec_noop = $areyousure ? {
		true => false,
		default => true,
	}

	# if we're on itself, and we have a real device to work with
	if (type($dev) != 'boolean') and ("${fqdn}" == "${host}") {

		# partitioning...
		if $partition {
			if $exec_noop {
				notify { "noop for partitioning: ${name}":
					message => "${part_mklabel} && ${part_mkpart}",
				}
			}

			exec { "${part_mklabel} && ${part_mkpart}":
				logoutput => on_failure,
				unless => [		# if one element is true, this *doesn't* run
					"/usr/bin/test -e ${dev1}",	# does the partition 1 exist ?
					'/bin/false',	# TODO: add more criteria
				],
				require => $exec_requires,
				timeout => 3600,	# TODO
				noop => $exec_noop,
				before => $lvm ? {	# if no lvm, skip to mkfs
					false => Exec["gluster-brick-mkfs-${name}"],
					default => Exec["gluster-brick-lvm-pvcreate-${name}"],
				},
				alias => "gluster-brick-partition-${name}",
			}
		}

		# lvm...
		if $lvm {
			if $exec_noop {
				notify { "noop for lvm: ${name}":
					message => "${lvm_pvcreate} && ${lvm_vgcreate} && ${lvm_lvcreate}",
				}
			}

			exec { "${lvm_pvcreate}":
				logoutput => on_failure,
				unless => [		# if one element is true, this *doesn't* run
					"${::gluster::params::program_pvdisplay} ${dev1}",
					'/bin/false',	# TODO: add more criteria
				],
				require => $exec_requires,
				timeout => 3600,	# set to something very long
				noop => $exec_noop,
				before => Exec["gluster-brick-lvm-vgcreate-${name}"],
				alias => "gluster-brick-lvm-pvcreate-${name}",
			}

			exec { "${lvm_vgcreate}":
				logoutput => on_failure,
				unless => [		# if one element is true, this *doesn't* run
					"${::gluster::params::program_vgdisplay} ${lvm_vgname}",
					'/bin/false',	# TODO: add more criteria
				],
				require => $exec_requires,
				timeout => 3600,	# set to something very long
				noop => $exec_noop,
				before => Exec["gluster-brick-lvm-lvcreate-${name}"],
				alias => "gluster-brick-lvm-vgcreate-${name}",
			}

			exec { "${lvm_lvcreate}":
				logoutput => on_failure,
				unless => [		# if one element is true, this *doesn't* run
					#"${::gluster::params::program_lvdisplay} ${lvm_lvname}",	# nope!
					"${::gluster::params::program_lvs} --separator ':' | /usr/bin/tr -d ' ' | ${::gluster::params::program_awk} -F ':' '{print \$1}' | /bin/grep -q '${lvm_lvname}'",
					'/bin/false',	# TODO: add more criteria
				],
				require => $exec_requires,
				timeout => 3600,	# set to something very long
				noop => $exec_noop,
				before => Exec["gluster-brick-mkfs-${name}"],
				alias => "gluster-brick-lvm-lvcreate-${name}",
			}
		}

		if $exec_noop {
			notify { "noop for mkfs: ${name}":
				message => "${mkfs_exec}",
			}
		} else {
			# if valid_fsuuid isn't ready, trigger an exec again...
			exec { "gluster-brick-fsuuid-execagain-${name}":
				command => '/bin/true',	# do nothing but notify
				logoutput => on_failure,
				onlyif => "/usr/bin/test -z '${valid_fsuuid}'",
				notify => $again ? {
					false => undef,
					default => Common::Again::Delta['gluster-exec-again'],
				},
				# this (optional) require makes it more logical
				require => File["${vardir}/brick/fsuuid/"],
			}
		}

		# mkfs...
		exec { "${mkfs_exec}":
			logoutput => on_failure,
			onlyif => "/usr/bin/test -n '${valid_fsuuid}'",
			unless => [		# if one element is true, this *doesn't* run
				"/usr/bin/test -e /dev/disk/by-uuid/${valid_fsuuid}",
				"${::gluster::params::program_findmnt} --output 'TARGET,SOURCE' -t ${valid_fstype} --target '${valid_path}' -n",
				'/bin/false',	# TODO: add more criteria
			],
			require => $exec_requires,
			timeout => 3600,	# set to something very long
			noop => $exec_noop,
			alias => "gluster-brick-mkfs-${name}",
		}

		# make an empty directory for the mount point
		file { "${valid_path}":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => false,		# don't purge unmanaged files
			force => false,		# don't purge subdirs and links
			require => Exec["gluster-brick-mkfs-${name}"],
		}

		# mount points don't seem to like trailing slashes...
		if "${valid_fsuuid}" != '' {	# in case fsuuid isn't ready yet
			mount { "${short_path}":
				atboot => true,
				ensure => mounted,
				device => "UUID=${valid_fsuuid}",
				fstype => "${valid_fstype}",
				# noatime,nodiratime to save gluster from silly updates
				options => "${mount_options},${ro_bool},noatime,nodiratime,noexec",	# TODO: is nodev? nosuid? noexec? a good idea?
				dump => '0',	# fs_freq: 0 to skip file system dumps
				# NOTE: technically this should be '2', to `fsck.xfs`
				# after the rootfs ('1'), but fsck.xfs actually does
				# 'nothing, successfully', so it's irrelevant, because
				# xfs uses xfs_check and friends only when suspect.
				pass => '2',	# fs_passno: 0 to skip fsck on boot
				require => [
					File["${valid_path}"],
				],
			}
		}

	} elsif ((type($dev) == 'boolean') and (! $dev)) and ("${fqdn}" == "${host}") {

		# ensure the full path exists!
		# TODO: is the mkdir needed ?
		exec { "/bin/mkdir -p '${valid_path}'":
			creates => "${valid_path}",
			logoutput => on_failure,
			noop => $exec_noop,
			alias => "gluster-brick-mkdir-${name}",
			before => File["${valid_path}"],
		}

		# avoid any possible purging of data!
		file { "${valid_path}":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => false,		# don't purge unmanaged files
			force => false,		# don't purge subdirs and links
			require => Exec["gluster-brick-mkfs-${name}"],
		}
	}
}

# vim: ts=8
