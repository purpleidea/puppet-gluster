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
require 'base64'	# TODO: i wish facter worked with types instead of hacks

# regexp to match gluster volume name, eg: testvolume
volume_regexp = /^[a-z]{1}[a-z0-9]{0,}$/	# TODO: is this perfect ?

# returns true if each brick in the list matches
def brick_match(l)
	# regexp to match a brick pattern, eg: annex1.example.com:/storage1a
	brick_regexp = /^[a-zA-Z]{1}[a-zA-Z0-9\.\-]{0,}:\/[a-zA-Z0-9]{1}[a-zA-Z0-9\/\.\-]{0,}$/	# TODO: is this perfect ?
	l.each do |x|
		if not brick_regexp.match(x)
			return false
		end
	end
	return true
end

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
	# if we can't get a valid vardirtmp, then we can't collect...
	fsm_dir = nil
else
	module_vardir = var+'gluster/'
	valid_dir = module_vardir.gsub(/\/$/, '')+'/'
	fsm_dir = valid_dir+'volume/fsm/'
end

state = {}
stack = {}
watch = {}

if not(fsm_dir.nil?) and File.directory?(fsm_dir)
	# loop through each sub directory in the gluster::volume fsm
	Dir.glob(fsm_dir+'*').each do |d|
		n = File.basename(d)	# should be the gluster::volume name
		if n.length > 0 and volume_regexp.match(n)

			f = d.gsub(/\/$/, '')+'/state'	# full file path
			if File.exists?(f)
				# TODO: future versions should unpickle (but with yaml)
				v = File.open(f, 'r').read.strip	# read into str
				if v.length > 0 and brick_match(v.split(','))
					state[n] = v
				end
			end

			f = d.gsub(/\/$/, '')+'/stack'	# full file path
			if File.exists?(f)
				stack[n] = []	# initialize empty array
				File.readlines(f).each do |l|
					l = l.strip	# clean off /n's
					# TODO: future versions should unpickle (but with yaml)
					if l.length > 0 and brick_match(l.split(','))
						#stack[n].push(l)
						stack[n].push(Base64.encode64(l).delete("\n"))
					end
				end
			end

			f = d.gsub(/\/$/, '')+'/watch'	# full file path
			if File.exists?(f)
				watch[n] = []	# initialize empty array
				File.readlines(f).each do |l|
					l = l.strip	# clean off /n's
					# TODO: future versions should unpickle (but with yaml)
					if l.length > 0 and brick_match(l.split(','))
						#watch[n].push(l)
						watch[n].push(Base64.encode64(l).delete("\n"))
					end
				end
			end

		end
	end
end

state.keys.each do |x|
	Facter.add('gluster_volume_fsm_state_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			state[x]
		}
	end

	if stack.key?(x)
		Facter.add('gluster_volume_fsm_stack_'+x) do
			#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
			setcode {
				stack[x].join(',')
			}
		end
	end

	if watch.key?(x)
		Facter.add('gluster_volume_fsm_watch_'+x) do
			#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
			setcode {
				watch[x].join(',')
			}
		end
	end
end

# list of gluster volume fsm state fact names
Facter.add('gluster_volume_fsm_states') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		state.keys.sort.collect {|x| 'gluster_volume_fsm_state_'+x }.join(',')
	}
end

Facter.add('gluster_volume_fsm_stacks') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		(state.keys & stack.keys).sort.collect {|x| 'gluster_volume_fsm_stack_'+x }.join(',')
	}
end

Facter.add('gluster_volume_fsm_watchs') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		(state.keys & watch.keys).sort.collect {|x| 'gluster_volume_fsm_watch_'+x }.join(',')
	}
end

Facter.add('gluster_fsm_debug') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		'Oh cool, james added fsm support to puppet-gluster. Sweet!'
	}
end

