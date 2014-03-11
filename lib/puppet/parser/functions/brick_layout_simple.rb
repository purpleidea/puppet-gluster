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

# NOTE:
# sort the bricks in a logical manner... i think this is the optimal algorithm,
# but i'd be happy if someone thinks they can do better! this assumes that the
# bricks and hosts are named in a logical manner. alphanumeric sorting is used
# to determine the default ordering...

module Puppet::Parser::Functions
	newfunction(:brick_layout_simple, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
		Return the simple symmetrical brick list

		Example:

			$layout = brick_layout_simple($replica, $bricks)
			notice("layout is: ${layout}")

		This function is used internally for automatic brick layouts.

		ENDHEREDOC

		# signature: replica, bricks -> bricks
		unless args.length == 2
			raise Puppet::ParseError, "brick_layout_simple(): wrong number of arguments (#{args.length}; must be 2)"
		end
		if not(args[0].is_a?(Integer)) and not(args[0].is_a?(String))
			# NOTE: strings that convert to int's with .to_i are ok
			raise Puppet::ParseError, "brick_layout_simple(): expects the first argument to be an integer, got #{args[0].inspect} which is of type #{args[0].class}"
		end
		unless args[1].is_a?(Array)
			raise Puppet::ParseError, "brick_layout_simple(): expects the first argument to be an array, got #{args[1].inspect} which is of type #{args[1].class}"
		end

		replica = args[0].to_i	# convert from string if needed
		bricks = args[1]

		# TODO: these functions could be in separate puppet files
		# eg: Puppet::Parser::Functions.function('myfunc')
		# function_myfunc(...)
		def brick_str_to_hash(bricks)
			# this loop converts brick strings to brick dict's...
			result = []
			bricks.each do |x|
				a = x.split(':')
				#assert a.length == 2	# TODO
				p = a[1]
				p = ((p[-1, 1] == '/') ? p : (p+'/'))	# endswith

				result.push({'host'=> a[0], 'path'=> p})
			end
			return result
		end

		collect = {}
		parsed = brick_str_to_hash(bricks)
		parsed.each do |x|
			key = x['host']
			val = x['path']

			if not collect.has_key?(key)
				collect[key] = []	# initialize
			end

			collect[key].push(val)	# save in array
			# TODO: ensure this array is always sorted (we could also do this after
			# or always insert elements in the correct sorted order too :P)
			collect[key] = collect[key].sort
		end

		# we also could do this sort here...
		collect.keys.each do |x|
			collect[x] = collect[x].sort
		end

		final = []	# final order...
		# TODO: here we can probably detect if this is an asymmetrical configurations, or maybe bad naming...
		while collect.size > 0
			collect.keys.sort.each do |x|

				# NOTE: this array should already be sorted!
				p = collect[x].shift	# assume an array of at least 1 element
				final.push( { 'host' => x, 'path' => p } )	# save

				if collect[x].size == 0		# maybe the array is empty now
					collect.delete(x)	# remove that empty list's key
				end
			end
		end

		# build final result
		result = final.collect {|x| x['host']+':'+x['path'] }
		result	# return
	end
end

# vim: ts=8
