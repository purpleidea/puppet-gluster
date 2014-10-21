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

module Puppet::Parser::Functions
	newfunction(:brick_str_to_hash, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
		Helper function for the brick layout algorithms.

		ENDHEREDOC

		# signature: replica, bricks -> bricks
		unless args.length == 1
			raise Puppet::ParseError, "brick_str_to_hash(): wrong number of arguments (#{args.length}; must be 1)"
		end
		unless args[0].is_a?(Array)
			raise Puppet::ParseError, "brick_str_to_hash(): expects the first argument to be an array, got #{args[0].inspect} which is of type #{args[0].class}"
		end

		bricks = args[0]
		# this loop converts brick strings to brick dict's...
		result = []
		bricks.each do |x|
			a = x.split(':')
			#assert a.length == 2	# TODO
			p = a[1]
			p = ((p[-1, 1] == '/') ? p : (p+'/'))	# endswith

			result.push({'host'=> a[0], 'path'=> p})
		end

		result	# return
	end
end

# vim: ts=8
