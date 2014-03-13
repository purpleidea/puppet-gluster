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
require 'digest/sha1'

# TODO: the ruby uuid method can be used when newer ruby versions are used here
# require 'securerandom'
# SecureRandom.uuid

# uuid regexp
regexp = /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/
fqdn = Facter.value('fqdn')			# this could be nil !

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
	module_vardir = nil
	valid_brickdir = nil
	uuiddir = nil
else
	module_vardir = var+'gluster/'
	valid_brickdir = module_vardir.gsub(/\/$/, '')+'/brick/'
	uuiddir = valid_brickdir+'fsuuid/'	# safe dir that won't get purged...
end

# NOTE: module specific mkdirs, needed to ensure there is no blocking/deadlock!
if not(var.nil?) and not File.directory?(var)
	Dir::mkdir(var)
end

if not(module_vardir.nil?) and not File.directory?(module_vardir)
	Dir::mkdir(module_vardir)
end

if not(valid_brickdir.nil?) and not File.directory?(valid_brickdir)
	Dir::mkdir(valid_brickdir)
end

found = {}

# generate uuid and parent directory if they don't already exist...
if not(valid_brickdir.nil?) and File.directory?(valid_brickdir)
	if not File.directory?(uuiddir)
		Dir::mkdir(uuiddir)
	end

	# loop through brick dir, looking for brick names to make fsuuid's for!
	if not(valid_brickdir.nil?) and File.directory?(valid_brickdir) and File.directory?(uuiddir)
		Dir.glob(valid_brickdir+'*.*').each do |f|
			b = File.basename(f)
			g = b.split('.')	# $name.group

			group = g.pop()		# pop off suffix (the group name)

			if g.length >= 1
				# NOTE: some of this code is unnecessary, but i
				# kept it because it matches the brick parsing.

				x = g.join('.')	# in case value had dots in it.

				brick = File.open(f, 'r').read.strip	# read into str
				# eg: annex1.example.com:/storage1a
				split = brick.split(':')	# do some $name parsing
				host = split[0]			# host fqdn
				# NOTE: technically $path should be everything BUT split[0]. This
				# lets our $path include colons if for some reason they're needed.
				#path = split[1]		# brick mount or storage path
				path = brick.slice(host.length+1, brick.length-host.length-1)

				# if fqdn is nil, generate for everyone...
				# (other hosts data will just be unused...)
				if not(fqdn.nil?)
					# otherwise, skip hosts that aren't us!
					if host != fqdn
						next
					end
				end

				uuidfile = uuiddir + b
				# we sha1 to prevent weird characters in facter
				key = Digest::SHA1.hexdigest(host + ':' + path + '.' + group)

				# create an fsuuid for each brick and store it
				# in our vardir if it doesn't already exist...
				if not File.exist?(uuidfile)
					result = system("/usr/bin/uuidgen > '" + uuidfile + "'")
					if not(result)
						# TODO: print warning
					end
				end

				# create facts from all the uuid files found...
				uuid = File.open(uuidfile, 'r').read.strip.downcase	# read into str
				if uuid.length == 36 and regexp.match(uuid)
					# avoid: http://projects.puppetlabs.com/issues/22455
					found[key] = uuid
				# TODO: print warning on else...
				end
			end
		end
	end
end

found.keys.each do |x|
	Facter.add('gluster_brick_fsuuid_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			found[x]
		}
	end
end

# list of generated gluster_brick_fsuuid's
Facter.add('gluster_brick_fsuuid_facts') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.collect {|x| 'gluster_brick_fsuuid_'+x }.join(',')
	}
end

# vim: ts=8
