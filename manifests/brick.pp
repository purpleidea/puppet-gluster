# Simple? gluster module by James
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
	$dev,				# /dev/sdc, /dev/disk/by-id/scsi-36003048007e14f0014ca2743150a5471
	$fsuuid,			# set a uuid for this fs (uuidgen)
	$labeltype = '',		# gpt
	$fstype = '',			# xfs
	$xfs_inode64 = false,
	$xfs_nobarrier = false,
	$ro = false,			# use for emergencies only- you want your fs rw
	$force = false,			# if true, this will overwrite any xfs fs it sees, useful for rebuilding gluster and wiping data. NOTE: there are other safeties in place to stop this.
	$areyousure = false		# do you allow puppet to do dangerous things ?
) {
	# eg: annex1.example.com:/storage1a
	$split = split($name, ':')	# do some $name parsing
	$host = $split[0]		# host fqdn
	# NOTE: technically $mount should be everything BUT split[0]. This
	# lets our $mount include colons if for some reason they're needed.
	#$mount = $split[1]		# brick mount
	# TODO: create substring function
	$mount = inline_template("<%= '${name}'.slice('${host}'.length+1, '${name}'.length-'${host}'.length-1) %>")

	if ! ( "${host}:${mount}" == "${name}" ) {
		fail('The brick $name must match a $host-$mount pattern.')
	}

	Gluster::Host[$host] -> Gluster::Brick[$name]	# brick requires host

	$ro_bool = $ro ? {		# this has been added as a convenience
		true => 'ro',
		default => 'rw',
	}

	$valid_labeltype = $labeltype ? {
		#'msdos' => 'msdos',	# TODO
		default => 'gpt',
	}

	$valid_fstype = $fstype ? {
		'ext4' => 'ext4',	# TODO
		default => 'xfs',
	}

	$force_flag = $force ? {
		true => 'f',
		default => '',
	}

	# XFS mount options:
	# http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=blob;f=Documentation/filesystems/xfs.txt;hb=HEAD
	if ( $valid_fstype == 'xfs' ) {
		# exec requires
		include gluster::brick::xfs
		$exec_requires = [Package['xfsprogs']]

		# mkfs w/ uuid command
		# NOTE: the -f forces creation when it sees an old xfs part
		# TODO: xfs_admin doesn't have a --quiet flag. silence it...
		$exec_mkfs = "/sbin/mkfs.${valid_fstype} -q${force_flag} `/bin/readlink -e ${dev}`1 && /usr/sbin/xfs_admin -U '${fsuuid}' `/bin/readlink -e ${dev}`1"

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

		$options_list = ["${option01}", "${option02}"]

	} elsif ( $valid_fstype == 'ext4' ) {
		# exec requires
		include gluster::brick::ext4
		$exec_requires = [Package['e2fsprogs']]

		# mkfs w/ uuid command
		$exec_mkfs = "/sbin/mkfs.${valid_fstype} -U '${fsuuid}' `/bin/readlink -e ${dev}`1"

		# mount options
		$options_list = []	# TODO
	}

	# put all the options in an array, remove the empty ones, and join with
	# commas (this removes ',,' double comma uglyness)
	# adding 'defaults' here ensures no ',' (leading comma) in mount command
	$mount_options = inline_template('<%= (["defaults"]+options_list).delete_if {|x| x.empty? }.join(",") %>')

	$exec_noop = $areyousure ? {
		true => false,
		default => true,
	}

	# if we're on itself
	if ( "${fqdn}" == "${host}" ) {

		# first get the device ready

		# the scary parted command to run...
		$exec_mklabel = "/sbin/parted -s -m -a optimal ${dev} mklabel ${valid_labeltype}"
		$exec_mkpart = "/sbin/parted -s -m -a optimal ${dev} mkpart primary 0% 100%"
		$scary_exec = "${exec_mklabel} && ${exec_mkpart} && ${exec_mkfs}"	# the command
		if $exec_noop {
			notify { "noop for ${name}":
				message => "${scary_exec}",
			}
		}

		exec { "${scary_exec}":
			logoutput => on_failure,
			unless => [		# if one element is true, this *doesn't* run
				"/usr/bin/test -e `/bin/readlink -e ${dev}`1",	# does partition 1 exist ?
				"/usr/bin/test -e /dev/disk/by-uuid/${fsuuid}",
				'/bin/false',	# TODO: add more criteria
			],
			require => $exec_requires,
			timeout => 3600,			# set to something very long
			noop => $exec_noop,
			alias => "gluster-brick-make-${name}",
		}

		# make an empty directory for the mount point
		file { "${mount}":
			ensure => directory,		# make sure this is a directory
			recurse => false,			# don't recurse into directory
			purge => false,			# don't purge unmanaged files
			force => false,			# don't purge subdirs and links
			require => Exec["gluster-brick-make-${name}"],
		}

		mount { "${mount}":
			atboot => true,
			ensure => mounted,
			device => "UUID=${fsuuid}",
			fstype => "${valid_fstype}",
			# noatime,nodiratime to save gluster from silly updates
			options => "${mount_options},${ro_bool},noatime,nodiratime,noexec",	# TODO: is nodev? nosuid? noexec? a good idea?
			dump => '0',			# fs_freq: 0 to skip file system dumps
			# NOTE: technically this should be '2', to `fsck.xfs`
			# after the rootfs ('1'), but fsck.xfs actually does
			# 'nothing, successfully', so it's irrelevant, because
			# xfs uses xfs_check and friends only when suspect.
			pass => '2',			# fs_passno: 0 to skip fsck on boot
			require => [
				File["${mount}"],
			],
		}
	}
}

# vim: ts=8
