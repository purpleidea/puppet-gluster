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
require 'ipaddr'

length = 16
# pass regexp
regexp = /^[a-zA-Z0-9]{#{length}}$/
ipregexp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
netmaskregexp = /^(((128|192|224|240|248|252|254)\.0\.0\.0)|(255\.(0|128|192|224|240|248|252|254)\.0\.0)|(255\.255\.(0|128|192|224|240|248|252|254)\.0)|(255\.255\.255\.(0|128|192|224|240|248|252|254)))$/
chars = [('a'..'z'), ('A'..'Z'), (0..9)].map { |i| i.to_a }.flatten


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
	vrrpdir = nil
	vrrpfile = nil
	ipfile = nil
else
	module_vardir = var+'gluster/'
	vrrpdir = module_vardir+'vrrp/'
	vrrpfile = vrrpdir+'vrrp'
	ipfile = vrrpdir+'ip'
end

# NOTE: module specific mkdirs, needed to ensure there is no blocking/deadlock!
if not(var.nil?) and not File.directory?(var)
	Dir::mkdir(var)
end

if not(module_vardir.nil?) and not File.directory?(module_vardir)
	Dir::mkdir(module_vardir)
end

if not(vrrpdir.nil?) and not File.directory?(vrrpdir)
	Dir::mkdir(vrrpdir)
end

# generate pass and parent directory if they don't already exist...
if not(module_vardir.nil?) and File.directory?(module_vardir)
	if not File.directory?(vrrpdir)
		Dir::mkdir(vrrpdir)
	end

	# create a pass and store it in our vardir if it doesn't already exist!
	if File.directory?(vrrpdir) and ((not File.exist?(vrrpfile)) or (File.size(vrrpfile) == 0))
		# include a built-in pwgen-like backup
		string = (0..length-1).map { chars[rand(chars.length)] }.join
		result = system("(/usr/bin/test -z /usr/bin/pwgen && /usr/bin/pwgen -N 1 #{length} || /bin/echo '#{string}') > '" + vrrpfile + "'")
		if not(result)
			# TODO: print warning
		end
	end
end

# create the fact if the vrrp file contains a valid pass
if not(vrrpfile.nil?) and File.exist?(vrrpfile)
	pass = File.open(vrrpfile, 'r').read.strip		# read into str
	# skip over pass's of the wrong length or that don't match (security!!)
	if pass.length == length and regexp.match(pass)
		Facter.add('gluster_vrrp') do
			#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
			setcode {
				# don't reuse pass variable to avoid bug #:
				# http://projects.puppetlabs.com/issues/22455
				pass
			}
		end
	# TODO: print warning on else...
	end
end

# create facts from externally collected vrrp files
_pass = ''
found = {}
prefix = 'vrrp_'
if not(vrrpdir.nil?) and File.directory?(vrrpdir)
	Dir.glob(vrrpdir+prefix+'*').each do |f|

		b = File.basename(f)
		# strip off leading prefix
		fqdn = b[prefix.length, b.length-prefix.length]

		_pass = File.open(f, 'r').read.strip.downcase	# read into str
		if _pass.length == length and regexp.match(_pass)
			# avoid: http://projects.puppetlabs.com/issues/22455
			found[fqdn] = _pass
		# TODO: print warning on else...
		end
	end
end

#found.keys.each do |x|
#	Facter.add('gluster_vrrp_'+x) do
#		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
#		setcode {
#			found[x]
#		}
#	end
#end

#Facter.add('gluster_vrrp_facts') do
#	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
#	setcode {
#		found.keys.collect {|x| 'gluster_vrrp_'+x }.join(',')
#	}
#end

# distributed password (uses a piece from each host)
collected = found.keys.sort.collect {|x| found[x] }.join('#')	# combine pieces
Facter.add('gluster_vrrp_password') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		Digest::SHA1.hexdigest(collected)
	}
end

Facter.add('gluster_vrrp_fqdns') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		# sorting is very important
		found.keys.sort.join(',')
	}
end

# create these facts if the ip file contains a valid ip address
if not(ipfile.nil?) and File.exist?(ipfile)
	ip = File.open(ipfile, 'r').read.strip.downcase	# read into str
	# skip over ip that doesn't match (security!!)
	if ipregexp.match(ip)

		# TODO: replace with system-getifaddrs if i can get it working!
		cmd = "/sbin/ip -o a show to #{ip} | /bin/awk '{print $2}'"
		interface = `#{cmd}`.strip
		if $?.exitstatus == 0 and interface.length > 0

			Facter.add('gluster_vrrp_interface') do
				#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
				setcode {
					interface
				}
			end

			# lookup from fact
			netmask = Facter.value('netmask_'+interface)
			if netmaskregexp.match(netmask)

				Facter.add('gluster_vrrp_netmask') do
					#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
					setcode {
						netmask
					}
				end

				cidr = IPAddr.new("#{netmask}").to_i.to_s(2).count('1')
				Facter.add('gluster_vrrp_cidr') do
					#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
					setcode {
						cidr
					}
				end
			end

		# TODO: print warning on else...
		end

	# TODO: print warning on else...
	end
end

# vim: ts=8
