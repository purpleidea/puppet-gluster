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

# TODO: the ruby uuid method can be used when newer ruby versions are used here
# require 'securerandom'
# SecureRandom.uuid

# uuid regexp
regexp = /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/

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
	uuiddir = nil
	uuidfile = nil
else
	module_vardir = var+'gluster/'
	uuiddir = module_vardir+'uuid/'	# safe dir that won't get purged...
	uuidfile = uuiddir+'uuid'
end

# NOTE: module specific mkdirs, needed to ensure there is no blocking/deadlock!
if not(var.nil?) and not File.directory?(var)
	Dir::mkdir(var)
end

if not(module_vardir.nil?) and not File.directory?(module_vardir)
	Dir::mkdir(module_vardir)
end

if not(uuiddir.nil?) and not File.directory?(uuiddir)
	Dir::mkdir(uuiddir)
end

# generate uuid and parent directory if they don't already exist...
if not(module_vardir.nil?) and File.directory?(module_vardir)
	if not File.directory?(uuiddir)
		Dir::mkdir(uuiddir)
	end

	# create a uuid and store it in our vardir if it doesn't already exist!
	if File.directory?(uuiddir) and (not File.exist?(uuidfile))
		result = system("/usr/bin/uuidgen > '" + uuidfile + "'")
		if not(result)
			# TODO: print warning
		end
	end
end

# create the fact if the uuid file contains a valid uuid
if not(uuidfile.nil?) and File.exist?(uuidfile)
	uuid = File.open(uuidfile, 'r').read.strip.downcase	# read into str
	# skip over uuid's of the wrong length or that don't match (security!!)
	if uuid.length == 36 and regexp.match(uuid)
		Facter.add('gluster_uuid') do
			#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
			setcode {
				# don't reuse uuid variable to avoid bug #:
				# http://projects.puppetlabs.com/issues/22455
				uuid
			}
		end
	# TODO: print warning on else...
	end
end

# create facts from externally collected uuid files
_uuid = ''
found = {}
prefix = 'uuid_'
if not(uuiddir.nil?) and File.directory?(uuiddir)
	Dir.glob(uuiddir+prefix+'*').each do |f|

		b = File.basename(f)
		# strip off leading prefix
		fqdn = b[prefix.length, b.length-prefix.length]

		_uuid = File.open(f, 'r').read.strip.downcase	# read into str
		if _uuid.length == 36 and regexp.match(_uuid)
			# avoid: http://projects.puppetlabs.com/issues/22455
			found[fqdn] = _uuid
		# TODO: print warning on else...
		end
	end
end

found.keys.each do |x|
	Facter.add('gluster_uuid_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			found[x]
		}
	end
end

# list of generated gluster_uuid's
Facter.add('gluster_uuid_facts') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.collect {|x| 'gluster_uuid_'+x }.join(',')
	}
end

Facter.add('gluster_fqdns') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.sort.join(',')
	}
end

# vim: ts=8
