#!/usr/bin/python
# -*- coding: utf-8 -*-
# Copyright (C) 2012  James Shubin <james@shubin.ca>
# Copyright (C) 2012  Jordi Gutiérrez Hermoso <jordigh@octave.org>
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

# thanks to Jordi for fighting with the xml for me so that I didn't have to :)

# 	EXAMPLE:
#	$ gluster volume --xml info <VOLNAME> | ./xml.py <KEY>
#	<VALUE>

import sys
import lxml.etree as etree

if len(sys.argv) != 2:
	sys.exit(1)

t = etree.parse(sys.stdin)
r = t.getroot()
v = [x.find('value').text for x in r.findall('.//option') if x.find('name').text == str(sys.argv[1])]
if len(v) == 1:
	print v[0]
	sys.exit(0)
else:			# more than one value found
	sys.exit(1)

