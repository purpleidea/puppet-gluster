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
	xmlfile = nil
else
	module_vardir = var+'gluster/'
	xmlfile = module_vardir+'xml.py'
end

host = Facter.value('fqdn')
found = {}

# we need the script installed first to be able to generate the port facts...
if not(xmlfile.nil?) and File.exist?(xmlfile)
	volumes = `/usr/sbin/gluster volume list`
	if $?.exitstatus == 0
		volumes.split.each do |x|
			# values come out as comma separated strings for direct usage
			cmd = '/usr/sbin/gluster volume status --xml | '+xmlfile+" ports --volume '"+x+"' --host '"+host+"'"
			result = `#{cmd}`
			if $?.exitstatus == 0
				found[x] = result
			# TODO: else, print warning
			end
		end
	# TODO: else, print warning
	end
end

found.keys.each do |x|
	Facter.add('gluster_ports_volume_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			# don't reuse single variable to avoid bug #:
			# http://projects.puppetlabs.com/issues/22455
			found[x]
		}
	end
end

# list of generated gluster_ports_volume's
Facter.add('gluster_ports_volumes_facts') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.collect {|x| 'gluster_ports_volume_'+x }.join(',')
	}
end

# vim: ts=8
