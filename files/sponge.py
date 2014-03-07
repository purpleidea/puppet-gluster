#!/usr/bin/python
# -*- coding: utf-8 -*-
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

# This is meant to be a replacement for the excellent 'sponge' utility from the
# 'moreutils' package by Joey Hess. It doesn't do exactly what sponge does, but
# it does to the extent of what is used here for this Puppet-Gluster module. It
# is useful for environments that do not have the sponge package in their repo.

import sys

x = sys.stdin.readlines()
# TODO: can we be certain to sync here, and that the compiler doesn't optimize?

if len(sys.argv) == 1:
	# stdout
	# TODO: untested
	for l in x: sys.stdout.write(l)
	sys.stdout.flush()

elif len(sys.argv) == 2:
	# file
	f = open(sys.argv[1], 'w')
	for l in x: f.write(l)
	f.close()

else:
	sys.exit(1)

# vim: ts=8
