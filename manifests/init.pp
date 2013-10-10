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

#
#	NOTES
#

#	* To rebuild gluster (erasing all data), rm -rf the storage dirs to
#	clear metadata. To do this without erasing data, read this article:
#	http://joejulian.name/blog/glusterfs-path-or-a-prefix-of-it-is-already-part-of-a-volume/
#
#	* List of state codes:
#		<MESSAGE>					<CODE>
#	static char *glusterd_friend_sm_state_names[] = {	# glusterd-sm.c
#		"Establishing Connection",			# 0
#		"Probe Sent to Peer",				# 1
#		"Probe Received from Peer",			# 2
#		"Peer in Cluster",				# 3 (verified)
#		"Accepted peer request",			# 4
#		"Sent and Received peer request",		# 5
#		"Peer Rejected",				# 6 (verified)
#		"Peer detach in progress",			# 7
#		"Probe Received from peer",			# 8
#		"Connected to Peer",				# 9
#		"Peer is connected and Accepted",		# 10
#		"Invalid State"					# 11
#	};
#
#	* To use this gluster module, it's recommended that all nodes receive
#	the same puppet configuration. Puppet is smart enough to know what to
#	run on each participating node. Watchout for the mild race condition.
#
#	* TODO: add more notes...

#
#	XXX: FIXME: TODO
#
# XXX: does parted align disks properly ?
# XXX: mkfs.xfs -ssize=4k /dev/sdc1 ?	# should "-s sector_size" be used ?	http://kb.lsi.com/KnowledgebaseArticle16187.aspx ?
# XXX: setup auth somehow... ip address based for now # XXX: use volume::property...

# FIXME: test this: https://bugzilla.redhat.com/show_bug.cgi?id=GLUSTER-3769
# FIXME: peering: maybe we can just specify a guid somewhere so that everyone peers together ?
# FIXME: can we setup gluster by using templated volume files instead ?

# TODO: package { 'xfsdump': ensure => present } is this useful for something ?
# TODO: find out when ports are actually necessary for version 3.3

# vim: ts=8
