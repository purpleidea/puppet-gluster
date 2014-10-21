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
	newfunction(:brick_layout_chained, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
		Return the complex chained brick list

		Example:

			$layout = brick_layout_chained($replica, $bricks)
			notice("layout is: ${layout}")

		This function is used internally for automatic brick layouts.

		ENDHEREDOC

		Puppet::Parser::Functions.function('warning')	# load function
		Puppet::Parser::Functions.function('brick_str_to_hash')	# load function
		Puppet::Parser::Functions.function('get_hostlist')	# load function
		Puppet::Parser::Functions.function('get_brickstacks')	# load function
		# signature: replica, bricks -> bricks
		unless args.length == 2
			raise Puppet::ParseError, "brick_layout_chained(): wrong number of arguments (#{args.length}; must be 2)"
		end
		if not(args[0].is_a?(Integer)) and not(args[0].is_a?(String))
			# NOTE: strings that convert to int's with .to_i are ok
			raise Puppet::ParseError, "brick_layout_chained(): expects the first argument to be an integer, got #{args[0].inspect} which is of type #{args[0].class}"
		end
		unless args[1].is_a?(Array)
			raise Puppet::ParseError, "brick_layout_chained(): expects the second argument to be an array, got #{args[1].inspect} which is of type #{args[1].class}"
		end

		replica = args[0].to_i	# convert from string if needed
		bricks = args[1]

		final = []
		pointer = 0
		parsed = function_brick_str_to_hash([bricks])
		# TODO: there should probably be a proper 'sorted' function for
		# hostnames, in case they aren't numbered sanely _WITH_ padding.
		hosts = function_get_hostlist([parsed]).sort
		brickstack = function_get_brickstacks([parsed, true])

		if bricks.length == 0; return []; end

		# FIXME: this works with homogeneous volumes only!
		while pointer < (hosts.length * brickstack[hosts[0]].length) do
			start = hosts[pointer % hosts.length]
			#puts "host is #{host}, pointer is: #{pointer}"

			index = 0
			while index < replica do
				host = hosts[(pointer+index) % hosts.length]
				#puts "host is #{host}, index is: #{index}"
				index+= 1

				path = brickstack[host].shift	# yoink
				if path.nil?
					function_warning(["brick_layout_chained(): brick list is not valid"])
					next
				end
				final.push({'host' => host, 'path' => path})	# save
			end
			pointer+=1
		end

		# build final result
		result = final.collect {|x| x['host']+':'+x['path'] }
		result	# return
	end
end

# vim: ts=8
