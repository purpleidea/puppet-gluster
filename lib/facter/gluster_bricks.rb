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

require 'facter'

# regexp to match a brick pattern, eg: annex1.example.com:/storage1a
regexp = /^[a-zA-Z]{1}[a-zA-Z0-9\.\-]{0,}:\/[a-zA-Z0-9]{1}[a-zA-Z0-9\/\.\-]{0,}$/	# TODO: is this right ?

# find the module_vardir
dir = Facter.value('puppet_vardirtmp')		# nil if missing
if dir.nil?					# let puppet decide if present!
	dir = Facter.value('puppet_vardir')
	if dir.nil?
		var = nil
	else
		var = dir.gsub(/\/$/, '')+'/'+'tmp/'	# ensure trailing slash
	end
else
	var = dir.gsub(/\/$/, '')+'/'
end

if var.nil?
	# if we can't get a valid vardirtmp, then we can't continue
	uuidfile = nil
else
	module_vardir = var+'gluster/'
	valid_brickdir = module_vardir.gsub(/\/$/, '')+'/brick/'
end

found = {}
result = {}

if not(valid_brickdir.nil?) and File.directory?(valid_brickdir)
	Dir.glob(valid_brickdir+'*.*').each do |f|
		b = File.basename(f)
		g = b.split('.')	# $name.group

		group = g.pop()		# pop off suffix (the group name)
		if not found.key?(group)
			found[group] = []	# initialize
		end

		if g.length >= 1
			x = g.join('.')	# in case value had dots in it.

			brick = File.open(f, 'r').read.strip	# read into str
			# eg: annex1.example.com:/storage1a
			split = brick.split(':')	# do some $name parsing
			host = split[0]			# host fqdn
			# NOTE: technically $path should be everything BUT split[0]. This
			# lets our $path include colons if for some reason they're needed.
			#path = split[1]		# brick mount or storage path
			path = brick.slice(host.length+1, brick.length-host.length-1)

			if brick.length > 0 and regexp.match(brick)
				found[group].push({'host' => host, 'path' => path})
			# TODO: print warning on else...
			end
		end
	end
end

# sort the bricks in a logical manner... i think this is the optimal algorithm,
# but i'd be happy if someone thinks they can do better! this assumes that the
# bricks and hosts are named in a logical manner. alphanumeric sorting is used
# to determine the default ordering...
# TODO: maybe this should be a puppet function instead of a fact... that way,
# if necessary, the function could also include the replica count, and other
# data as input... is it even needed ?

found.keys.each do |group|

	collect = {}
	found[group].each do |x|
		key = x['host']
		val = x['path']

		if not collect.has_key?(key)
			collect[key] = []	# initialize
		end

		collect[key].push(val)	# save in array
		# TODO: ensure this array is always sorted (we could also do this after
		# or always insert elements in the correct sorted order too :P)
		collect[key] = collect[key].sort
	end

	# we also could do this sort here...
	collect.keys.each do |x|
		collect[x] = collect[x].sort
	end

	final = []	# final order...
	# TODO: here we can probably detect if this is an asymmetrical configurations, or maybe bad naming...
	while collect.size > 0
		collect.keys.sort.each do |x|

			# NOTE: this array should already be sorted!
			p = collect[x].shift	# assume an array of at least 1 element
			final.push( { 'host' => x, 'path' => p } )	# save

			if collect[x].size == 0		# maybe the array is empty now
				collect.delete(x)	# remove that empty list's key
			end

		end
	end

	# build final result
	result[group] = final.collect {|x| x['host']+':'+x['path'] }
end

# build the correctly sorted brick list...
result.keys.each do |x|
	Facter.add('gluster_brick_group_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			# don't reuse single variable to avoid bug #:
			# http://projects.puppetlabs.com/issues/22455
			# TODO: facter should support native list types :)
			result[x].join(',')
		}
	end
end

# list of generated gluster_ports_volume's
Facter.add('gluster_brick_group_facts') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		result.keys.collect {|x| 'gluster_brick_group_'+x }.join(',')
	}
end

# vim: ts=8
