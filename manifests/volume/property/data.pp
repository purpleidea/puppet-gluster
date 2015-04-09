# GlusterFS module by James
# Copyright (C) 2012-2013+ James Shubin
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

class gluster::volume::property::data() {

	# expected type
	$etypes = {

		# Allow a comma separated list of addresses and/or hostnames to connect to the server. By default, all connections are allowed.
		'auth.allow' => 'array',	# default: (null)

		# Reject a comma separated list of addresses and/or hostnames to connect to the server. By default, all connections are allowed.
		'auth.reject' => 'array',	# default: (null)

		# This specifies the number of self-heals that can be performed in background without blocking the fop
		'cluster.background-self-heal-count' => 'integer',	# default: 16

		# Choose a local subvolume (i.e. Brick) to read from if read-subvolume is not explicitly set.
		'cluster.choose-local' => 'truefalse',	# default: true

		# Data fops like write/truncate will not perform pre/post fop changelog operations in afr transaction if this option is disabled
		'cluster.data-change-log' => 'onoff',	# default: on

		# Using this option we can enable/disable data self-heal on the file. "open" means data self-heal action will only be triggered by file open operations.
		'cluster.data-self-heal' => 'onoff',	# default: on

		# Select between "full", "diff". The "full" algorithm copies the entire file from source to sink. The "diff" algorithm copies to sink only those blocks whose checksums don't match with those of source. If no option is configured the option is chosen dynamically as follows: If the file does not exist on one of the sinks or empty file exists or if the source file size is about the same as page size the entire file will be read and written i.e "full" algo, otherwise "diff" algo is chosen.
		'cluster.data-self-heal-algorithm' => 'string',	# default: (reset)

		# Lock phase of a transaction has two sub-phases. First is an attempt to acquire locks in parallel by broadcasting non-blocking lock requests. If lock acquisition fails on any server, then the held locks are unlocked and revert to a blocking locked mode sequentially on one server after another. If this option is enabled the initial broadcasting lock request attempt to acquire lock on the entire file. If this fails, we revert back to the sequential "regional" blocking lock as before. In the case where such an "eager" lock is granted in the non-blocking phase, it gives rise to an opportunity for optimization. i.e, if the next write transaction on the same FD arrives before the unlock phase of the first transaction, it "takes over" the full file lock. Similarly if yet another data transaction arrives before the unlock phase of the "optimized" transaction, that in turn "takes over" the lock as well. The actual unlock now happens at the end of the last "optimized" transaction.
		'cluster.eager-lock' => 'onoff',	# default: on

		# Entry fops like create/unlink will not perform pre/post fop changelog operations in afr transaction if this option is disabled
		'cluster.entry-change-log' => 'onoff',	# default: on

		# Using this option we can enable/disable entry self-heal on the directory.
		'cluster.entry-self-heal' => 'onoff',	# default: on

		# time interval for checking the need to self-heal in self-heal-daemon
		'cluster.heal-timeout' => 'integer',	# default: 600

		# This option if set to ON, does a lookup through all the sub-volumes, in case a lookup didn't return any result from the hash subvolume. If set to OFF, it does not do a lookup on the remaining subvolumes.
		'cluster.lookup-unhashed' => 'onoff',	# default: on

		# Metadata fops like setattr/setxattr will not perform pre/post fop changelog operations in afr transaction if this option is disabled
		'cluster.metadata-change-log' => 'onoff',	# default: on

		# Using this option we can enable/disable metadata i.e. Permissions, ownerships, xattrs self-heal on the file/directory.
		'cluster.metadata-self-heal' => 'onoff',	# default: on

		# Percentage/Size of disk space, after which the process starts balancing out the cluster, and logs will appear in log files
		'cluster.min-free-disk' => 'string',	# default: 10%

		# after system has only N% of inodes, warnings starts to appear in log files
		'cluster.min-free-inodes' => 'string',	# default: 5%

		# If quorum-type is "fixed" only allow writes if this many bricks or present. Other quorum types will OVERWRITE this value.
		'cluster.quorum-count' => 'integer',	# default: (null)

		# If value is "fixed" only allow writes if quorum-count bricks are present. If value is "auto" only allow writes if more than half of bricks, or exactly half including the first, are present.
		'cluster.quorum-type' => 'string',	# default: none

		# readdir(p) will not failover if this option is off
		'cluster.readdir-failover' => 'onoff',	# default: on

		# This option if set to ON enables the optimization that allows DHT to requests non-first subvolumes to filter out directory entries.
		'cluster.readdir-optimize' => 'offon',	# default: off

		# inode-read fops happen only on one of the bricks in replicate. AFR will prefer the one computed using the method specified using this option0 = first responder, 1 = hash by GFID of file (all clients use same subvolume), 2 = hash by GFID of file and client PID
		'cluster.read-hash-mode' => 'integer',	# default: 0

		# inode-read fops happen only on one of the bricks in replicate. Afr will prefer the one specified using this option if it is not stale. Option value must be one of the xlator names of the children. Ex: <volname>-client-0 till <volname>-client-<number-of-bricks - 1>
		'cluster.read-subvolume' => 'string',	# default: (null)

		# inode-read fops happen only on one of the bricks in replicate. AFR will prefer the one specified using this option if it is not stale. allowed options include -1 till replica-count - 1
		'cluster.read-subvolume-index' => 'integer',	# default: -1

		# This option if set to ON displays and logs the time taken for migration of each file, during the rebalance process. If set to OFF, the rebalance logs will only display the time spent in each directory.
		'cluster.rebalance-stats' => 'offon',	# default: off

		# This option applies to only self-heal-daemon. Index directory crawl and automatic healing of files will not be performed if this option is turned off.
		'cluster.self-heal-daemon' => 'offon',	# default: off

		# readdirp size for performing entry self-heal
		'cluster.self-heal-readdir-size' => 'integer',	# default: 1024 - Min 1024 Max 131072

		# Maximum number blocks per file for which self-heal process would be applied simultaneously.
		'cluster.self-heal-window-size' => 'integer',	# default: 1

		# Sets the quorum percentage for the trusted storage pool.
		'cluster.server-quorum-ratio' => 'integer',	# in % default: (null)

		# If set to server, enables the specified volume to participate in quorum.
		'cluster.server-quorum-type' => 'string',	# default: (null)

		# Size of the stripe unit that would be read from or written to the striped servers.
		'cluster.stripe-block-size' => 'string',	# default: 128KB

		# Enable coalesce mode to flatten striped files as stored on the server (i.e., eliminate holes caused by the traditional format).
		'cluster.stripe-coalesce' => 'falsetrue',	# default: false

		# Specifies the directory layout spread.
		'cluster.subvols-per-directory' => 'integer',	# default: (null)

		# Changes the log-level of the bricks
		'diagnostics.brick-log-level' => 'string',	# default: INFO

		# Gluster's syslog log-level
		'diagnostics.brick-sys-log-level' => 'string',	# default: CRITICAL

		# Changes the log-level of the clients
		'diagnostics.client-log-level' => 'string',	# default: INFO

		# Gluster's syslog log-level
		'diagnostics.client-sys-log-level' => 'string',	# default: CRITICAL

		# If on stats related to file-operations would be tracked inside GlusterFS data-structures.
		'diagnostics.dump-fd-stats' => 'offon',	# default: off

		# If on stats related to the latency of each operation would be tracked inside GlusterFS data-structures.
		'diagnostics.latency-measurement' => 'offon',	# default: off

		# Sets the grace-timeout value. Valid range 10-1800.
		'features.grace-timeout' => 'integer',	# default: (null)

		# Enables or disables the lock heal.
		'features.lock-heal' => 'offon',	# default: off

		# quota caches the directory sizes on client. Timeout indicates the timeout for the cache to be revalidated.
		'features.quota-timeout' => 'integer',	# default: 0

		# Time frame after which the (file) operation would be declared as dead, if the server does not respond for a particular (file) operation.
		'network.frame-timeout' => 'integer',	# default: 1800

		# Specifies the maximum megabytes of memory to be used in the inode cache.
		'network.inode-lru-limit' => 'integer',	# default: 16384

		# Time duration for which the client waits to check if the server is responsive.
		'network.ping-timeout' => 'integer',	# default: 42

		# If enabled, in open() and creat() calls, O_DIRECT flag will be filtered at the client protocol level so server will still continue to cache the file. This works similar to NFS's behavior of O_DIRECT
		'network.remote-dio' => 'string',	# default: disable

		# XXX: this appears twice
		# Specifies the window size for tcp socket.
		'network.tcp-window-size' => 'integer',	# default: (null)

		# This option is used to enable or disable ACL over NFS
		'nfs.acl' => 'onoff', # default: on

		# Users have the option of turning on name lookup for incoming client connections using this option. Use this option to turn on name lookups during address-based authentication. Turning this on will enable you to use hostnames in rpc-auth.addr.* filters. In some setups, the name server can take too long to reply to DNS queries resulting in timeouts of mount requests. By default, name lookup is off
		'nfs.addr-namelookup' => 'offon',	# default: (off)

		# This option is used to start or stop NFS server for individual volume.
		'nfs.disable' => 'offon',	# default: (off)

		# Internal option set to tell gnfs to use a different scheme for encoding file handles when DVM is being used.
		'nfs.dynamic-volumes' => 'offon',	# default: (off)

		# For nfs clients or apps that do not support 64-bit inode numbers, use this option to make NFS return 32-bit inode numbers instead. Disabled by default, so NFS returns 64-bit inode numbers.
		'nfs.enable-ino32' => 'offon',	# default: (off)

		# By default, all subvolumes of nfs are exported as individual exports. There are cases where a subdirectory or subdirectories in the volume need to be exported separately. This option can also be used in conjunction with nfs3.export-volumes option to restrict exports only to the subdirectories specified through this option. Must be an absolute path.
		'nfs.export-dir' => 'string',	# default: (null)

		# By default, all subvolumes of nfs are exported as individual exports. There are cases where a subdirectory or subdirectories in the volume need to be exported separately. Enabling this option allows any directory on a volumes to be exported separately. Directory exports are enabled by default.
		'nfs.export-dirs' => 'onoff',	# default: (on)

		# Enable or disable exporting whole volumes, instead if used in conjunction with nfs3.export-dir, can allow setting up only subdirectories as exports. On by default.
		'nfs.export-volumes' => 'onoff',	# default: (on)

		# Use this option to make NFS be faster on systems by using more memory. This option specifies a multiple that determines the total amount of memory used. Default value is 15. Increase to use more memory in order to improve performance for certain use cases. Please consult gluster-users list before using this option.
		'nfs.mem-factor' => 'integer',	# default: (null)

		# set the option to 'on' to enable mountd on UDP. Required for some Solaris and AIX NFS clients. The need for enabling this option often depends on the usage of NLM.
		'nfs.mount-udp' => 'offon',	# default: (off)

		# Use this option to change the the path for persistent caching of connected NFS-clients. For better perfomance this path should point to SHM
		'nfs.mount-rmtab' => 'string',	# default /var/lib/glusterd/nfs/rmtab

		# This option, if set to 'off', disables NLM server by not registering the service with the portmapper. Set it to 'on' to re-enable it. Default value: 'on'
		'nfs.nlm' => 'onoff',	# default: (on)

		# Use this option on systems that need Gluster NFS to be associated with a non-default port number.
		'nfs.port' => 'integer',	# default: (null)

		# Allow client connections from unprivileged ports. By default only privileged ports are allowed. Use this option to enable or disable insecure ports for a specific subvolume and to override the global setting set by the previous option.
		'nfs.ports-insecure' => 'offon',	# default: (off)

		# For systems that need to run multiple nfs servers, only one registration is possible with portmap service. Use this option to turn off portmap registration for Gluster NFS. On by default
		'nfs.register-with-portmap' => 'onoff',	# default: (on)

		# Allow a comma separated list of addresses and/or hostnames to connect to the server. By default, all connections are allowed. This allows users to define a rule for a specific exported volume.
		'nfs.rpc-auth-allow' => 'array',	# default: (null)

		# Disable or enable the AUTH_NULL authentication type for a particular exported volume overriding defaults and general setting for AUTH_NULL. Must always be enabled. This option is here only to avoid unrecognized option warnings.
		'nfs.rpc-auth-null' => 'onoff',	# default: (on)

		# Reject a comma separated list of addresses and/or hostnames from connecting to the server. By default, all connections are allowed. This allows users to define a rule for a specific exported volume.
		'nfs.rpc-auth-reject' => 'array',	# default: (null)

		# Disable or enable the AUTH_UNIX authentication type for a particular exported volume overriding defaults and general setting for AUTH_UNIX scheme. Must always be enabled for better interoperability.However, can be disabled if needed. Enabled by default.
		'nfs.rpc-auth-unix' => 'onoff',	# default: (on)

		# Specifies the nfs transport type. Valid transport types are 'tcp' and 'rdma'.
		'nfs.transport-type' => 'string',	# default: tcp

		# All writes and COMMIT requests are treated as async. This implies that no write requests are guaranteed to be on server disks when the write reply is received at the NFS client. Trusted sync includes trusted-write behaviour. Off by default.
		'nfs.trusted-sync' => 'offon',	# default: (off)

		# On an UNSTABLE write from client, return STABLE flag to force client to not send a COMMIT request. In some environments, combined with a replicated GlusterFS setup, this option can improve write performance. This flag allows user to trust Gluster replication logic to sync data to the disks and recover when required. COMMIT requests if received will be handled in a default manner by fsyncing. STABLE writes are still handled in a sync manner. Off by default.
		'nfs.trusted-write' => 'offon',	# default: (off)

		# Type of access desired for this subvolume: read-only, read-write(default)
		'nfs.volume-access' => 'string',	# default: (read-write)

		# Maximum file size which would be cached by the io-cache translator.
		'performance.cache-max-file-size' => 'integer',	# default: 0

		# Minimum file size which would be cached by the io-cache translator.
		'performance.cache-min-file-size' => 'integer',	# default: 0

		# Assigns priority to filenames with specific patterns so that when a page needs to be ejected out of the cache, the page of a file whose priority is the lowest will be ejected earlier
		'performance.cache-priority' => 'string',	# default:

		# The cached data for a file will be retained till 'cache-refresh-timeout' seconds, after which data re-validation is performed.
		'performance.cache-refresh-timeout' => 'integer',	# default: 1

		# XXX: this appears twice, with different defaults !
		# Size of the read cache.
		'performance.cache-size' => 'string',	# default: 32MB

		# Size of the read cache.
		'performance.cache-size' => 'string',	# default: 128MB

		# enable/disable io-threads translator in the client graph of volume.
		'performance.client-io-threads' => 'offon',	# default: off

		# Enable/Disable least priority
		'performance.enable-least-priority' => 'onoff',	# default: on

		# If this option is set ON, instructs write-behind translator to perform flush in background, by returning success (or any errors, if any of previous writes were failed) to application even before flush FOP is sent to backend filesystem.
		'performance.flush-behind' => 'onoff',	# default: on

		# Convert all readdir requests to readdirplus to collect stat info on each entry.
		'performance.force-readdirp' => 'onoff',	# default: on

		# Max number of threads in IO threads translator which perform high priority IO operations at a given time
		'performance.high-prio-threads' => 'integer',	# default: 16

		# enable/disable io-cache translator in the volume.
		'performance.io-cache' => 'onoff',	# default: on

		# Number of threads in IO threads translator which perform concurrent IO operations
		'performance.io-thread-count' => 'integer',	# default: 16

		# Max number of threads in IO threads translator which perform least priority IO operations at a given time
		'performance.least-prio-threads' => 'integer',	# default: 1

		# Max number of least priority operations to handle per-second
		'performance.least-rate-limit' => 'integer',	# default: 0

		# Max number of threads in IO threads translator which perform low priority IO operations at a given time
		'performance.low-prio-threads' => 'integer',	# default: 16

		# Time period after which cache has to be refreshed
		'performance.md-cache-timeout' => 'integer',	# default: 1

		# Max number of threads in IO threads translator which perform normal priority IO operations at a given time
		'performance.normal-prio-threads' => 'integer',	# default: 16

		# enable/disable open-behind translator in the volume.
		'performance.open-behind' => 'onoff',	# default: on

		# enable/disable quick-read translator in the volume.
		'performance.quick-read' => 'onoff',	# default: on

		# enable/disable read-ahead translator in the volume.
		'performance.read-ahead' => 'onoff',	# default: on

		# Number of pages that will be pre-fetched
		'performance.read-ahead-page-count' => 'integer',	# default: 4

		# enable/disable meta-data caching translator in the volume.
		'performance.stat-prefetch' => 'onoff',	# default: on

		# This option when set to off, ignores the O_DIRECT flag.
		'performance.strict-o-direct' => 'offon',	# default: off

		# Do not let later writes overtake earlier writes even if they do not overlap
		'performance.strict-write-ordering' => 'offon',	# default: off

		# enable/disable write-behind translator in the volume.
		'performance.write-behind' => 'onoff',	# default: on

		# Size of the write-behind buffer for a single file (inode).
		'performance.write-behind-window-size' => 'string',	# default: 1MB

		# NOTE: this option taken from gluster documentation
		# Allow client connections from unprivileged ports. By default only privileged ports are allowed. This is a global setting in case insecure ports are to be enabled for all exports using a single option.
		'server.allow-insecure' => 'offon',	# XXX: description and manual differ in their mention of what the correct default is, so which is it?

		# Map requests from uid/gid 0 to the anonymous uid/gid. Note that this does not apply to any other uids or gids that might be equally sensitive, such as user bin or group staff.
		'server.root-squash' => 'offon',	# default: off

		# Specifies directory in which gluster should save its statedumps. By default it is the /tmp directory
		'server.statedump-path' => 'string',	# default: /var/run/gluster

		# Support for native Linux AIO
		'storage.linux-aio' => 'offon',	# default: off

		# Support for setting gid of brick's owner
		'storage.owner-gid' => 'integer',	# default: (null)

		# Support for setting uid of brick's owner
		'storage.owner-uid' => 'integer',	# default: (null)
	}

	# join char
	$jchars = {
		'auth.allow' => ',',
		'auth.reject' => ',',
		'nfs.rpc-auth-allow' => ',',
		'nfs.rpc-auth-reject' => ',',
	}
}

# vim: ts=8
