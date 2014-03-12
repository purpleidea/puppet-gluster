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
	valid_brickdir = nil
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

# transform to strings
found.keys.each do |group|
	# build final result
	result[group] = found[group].collect {|x| x['host']+':'+x['path'] }
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
