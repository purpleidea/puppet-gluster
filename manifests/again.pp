# GlusterFS module by James
# Copyright (C) 2012-2013+ James Shubin
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

# NOTE: use with:
# notify => Common::Again::Delta['gluster-exec-again'],

# NOTE: this should be attached to the logical (often last) thing that, when it
# runs, means or is a signal that something more is going to happen in the next
# puppet run, and that stuff that is going to happen is useful to what just did
# run, which is why we don't want to wait for it to happen naturally in 30 min.

class gluster::again {

	# TODO: we could include an option to disable this exec again and
	# replace it with a "dummy" noop if someone doesn't want to use it.
	include common::again

	# when notified, this will run puppet again, delta sec after it ends!
	common::again::delta { 'gluster-exec-again':
		delta => 120,	# 2 minutes
	}

}

# vim: ts=8
