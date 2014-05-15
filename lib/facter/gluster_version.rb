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

# get the gluster path. this fact comes from an external fact set in: params.pp
gluster = Facter.value('gluster_program_gluster').to_s.chomp
if gluster == ''
	gluster = `which gluster 2> /dev/null`.chomp
	if gluster == ''
		gluster = '/usr/sbin/gluster'
	end
end

# create the fact if the gluster executable exists
if File.exist?(gluster)
	Facter.add('gluster_version') do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			Facter::Util::Resolution.exec(gluster+' --version | /usr/bin/head -1 | /bin/cut -d " " -f 2').chomp
		}
	end
end

# vim: ts=8
