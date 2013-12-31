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

class gluster::wrapper(
	$nodetree,
	$volumetree,
	$vip = '',		# vip of the cluster (optional but recommended)

	$nfs = false,								# TODO in server.pp
	$shorewall = false,
	$zone = 'net',								# TODO: allow a list of zones
	$allow = 'all'
) {
	#
	#	build gluster::server
	#

	$hosts = split(inline_template("<%= @nodetree.keys.join(',') %>"), ',')
	$ips = split(inline_template('<%= @nodetree.map{ |host,value| \'#{value["ip"]}\' }.join(",") %>'), ',')

	class { 'gluster::server':
		hosts => $hosts,
		ips => $ips,
#XXX: TODO?	clients => XXX,
		nfs => $nfs,
		shorewall => $shorewall,
		zone => $zone,
		allow => $allow,
	}

	#
	#	build gluster::host
	#

	# EXAMPLE:
	#gluster::host { 'annex1.example.com':
	#	# use uuidgen to make these
	#	uuid => '1f660ca2-2c78-4aa0-8f4d-21608218c69c',
	#}

	# filter the nodetree so that only host elements with uuid's are left
	# XXX: each_with_object doesn't exist in rhel6 ruby, so use inject
	#$hosttree = inline_template('<%= @nodetree.each_with_object({}) {|(x,y), h| h[x] = y.select{ |key,value| ["uuid"].include?(key) } }.to_yaml %>')
	$hosttree = inline_template('<%= @nodetree.inject({}) {|h, (x,y)| h[x] = y.select{ |key,value| ["uuid"].include?(key) }; h }.to_yaml %>')
	# newhash = oldhash.inject({}) { |h,(k,v)| h[k] = some_operation(v); h }	# XXX: does this form work ?
	$yaml_host = parseyaml($hosttree)
	create_resources('gluster::host', $yaml_host)

	#
	#	build gluster::brick
	#

	# EXAMPLE:
	#gluster::brick { 'annex1.example.com:/mnt/storage1a':
	#	dev => '/dev/disk/by-id/scsi-36003048007e26c00173ad3b633a2ef67',	# /dev/sda
	#	labeltype => 'gpt',
	#	fstype => 'xfs',
	#	fsuuid => '1ae49642-7f34-4886-8d23-685d13867fb1',
	#	xfs_inode64 => true,
	#	xfs_nobarrier => true,
	#	areyousure => true,
	#}

	# filter the nodetree and build out each brick element from the hosts
	$bricktree = inline_template('<%= r = {}; @nodetree.each {|x,y| y["bricks"].each {|k,v| r[x+":"+k] = v} }; r.to_yaml %>')
	# this version removes any invalid keys from the brick specifications
	#$bricktree = inline_template('<%= r = {}; @nodetree.each {|x,y| y["bricks"].each {|k,v| r[x+":"+k] = v.select{ |key,value| ["dev", "labeltype", "fstype", "fsuuid", "..."].include?(key) } } }; r.to_yaml %>')
	$yaml_brick = parseyaml($bricktree)
	create_resources('gluster::brick', $yaml_brick)

	#
	#	build gluster::volume
	#

	# EXAMPLE:
	#gluster::volume { 'examplevol':
	#	replica => 2,
	#	bricks => $brick_list,
	#	start => undef,	# i'll start this myself
	#}

	# to be used as default gluster::volume brick list
	$bricklist = split(inline_template("<%= @bricktree.keys.join(',') %>"), ',')

	# semi ok method:
	#$volumetree_defaults_all = {
	#	"bricks" => $bricklist,
	#	"transport" => 'tcp',
	#	"replica" => 1,
	#	"stripe" => 1,
	#	"vip" => $vip,
	#	"start" => undef,	# ?
	#}
	#$semi_ok = inline_template('<%= @volumetree.each_with_object({}) {|(x,y), h| h[x] = @volumetree_defaults_all.each_with_object({}) {|(xx,yy), hh| hh[xx] = y.fetch(xx, @volumetree_defaults_all[xx])} }.to_yaml %>')

	# good method
	$volumetree_defaults = {
		'bricks' => $bricklist,
		'vip' => $vip,
	}
	# loop through volumetree... if special defaults are missing, then add!
	$volumetree_updated = inline_template('<%= @volumetree.each_with_object({}) {|(x,y), h| h[x] = y; @volumetree_defaults.each {|k,v| h[k] = h.fetch(k, v)} }.to_yaml %>')
	$yaml_volume = parseyaml($volumetree_updated)
	create_resources('gluster::volume', $yaml_volume)

	#
	#	build gluster::volume::property (auth.allow)
	#

	# EXAMPLE:
	#gluster::volume::property { 'examplevol#auth.allow':
	#	value => '192.0.2.13,198.51.100.42,203.0.113.69',
	#}

	#$simplewrongname = inline_template('<%= @volumetree.each_with_object({}) {|(x,y), h| h[x+"#auth.allow"] = y.select{ |key,value| ["clients"].include?(key) } }.to_yaml %>')
	$propertytree = inline_template('<%= @volumetree.each_with_object({}) {|(x,y), h| h[x+"#auth.allow"] = { "value" => y.fetch("clients", []) } }.to_yaml %>')
	$yaml_volume_property = parseyaml($propertytree)
	create_resources('gluster::volume::property', $yaml_volume_property)
}

# vim: ts=8
