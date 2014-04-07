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

class gluster::params(
	$package_glusterfs = 'glusterfs',
	$package_glusterfs_fuse = 'glusterfs-fuse',
	$package_glusterfs_server = 'glusterfs-server',
	$package_glusterfs_api = 'glusterfs-api',

	$package_e2fsprogs = 'e2fsprogs',
	$package_xfsprogs = 'xfsprogs',

	$package_python_argparse = 'python-argparse',
	$package_python_lxml = 'python-lxml',
	$package_fping = 'fping',

	$comment = ''
) {
	if "${comment}" == '' {
		warning('Unable to load yaml data/ directory!')
	}

}
# vim: ts=8
