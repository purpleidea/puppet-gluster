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
	newfunction(:get_brickstacks, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
		Helper function for the brick layout algorithms.

		ENDHEREDOC

		Puppet::Parser::Functions.function('get_hostlist')	# load function

		# signature: replica, bricks -> bricks
		unless args.length == 2
			raise Puppet::ParseError, "get_brickstacks(): wrong number of arguments (#{args.length}; must be 2)"
		end
		unless args[0].is_a?(Array)
			raise Puppet::ParseError, "get_brickstacks(): expects the first argument to be an array, got #{args[0].inspect} which is of type #{args[0].class}"
		end
		unless args[1].is_a?(TrueClass) or args[1].is_a?(FalseClass)
			raise Puppet::ParseError, "get_brickstacks(): expects the second argument to be a boolean, got #{args[1].inspect} which is of type #{args[1].class}"
		end

		bricks = args[0]
		sort = args[1]

		stacks = {}
		hosts = function_get_hostlist([bricks])
		bricks.each do |x|
			key = x['host']
			val = x['path']
			if not stacks.include?(key); stacks[key] = []; end	# initialize
			stacks[key].push(val)
		end

		# optionally sort the paths in each individual host stack...
		if sort
			sorted_stacks = {}
			stacks.each do |k, v|
				# TODO: there should probably be a proper 'sorted' function for
				# paths, in case they aren't numbered sanely _WITH_ padding.
				sorted_stacks[k] = v.sort
			end
			stacks = sorted_stacks
		end

		stacks	# return
	end
end

# vim: ts=8
