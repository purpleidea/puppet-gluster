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

# 	EXAMPLE:
#	$ gluster peer status --xml | ./xml.py --connected <PEER1> <PEER2> <PEERn>
#	<BOOL>

# 	EXAMPLE:
#	$ gluster volume --xml info <VOLNAME> | ./xml.py --property <KEY>
#	<VALUE>

import sys
import lxml.etree as etree

argv = sys.argv
argv.pop(0)	# get rid of $0

if len(argv) < 1:
	sys.exit(3)

mode = argv.pop(0)
tree = etree.parse(sys.stdin)
root = tree.getroot()

# are all the hostnames in argv connected ?
if mode == '--connected':
	store = {}
	peers = [x for x in argv if x != '']

	for i in root.findall('.//peerStatus'):
		p = i.find('peer')
		h = p.find('hostname').text
		c = (str(p.find('connected').text) == '1')	# connected
		store[h] = c	# save for later...

	# if no peers specified, assume we should check all...
	if len(peers) == 0:
		peers = store.keys()

	for i in peers:
		if i in store.keys():
			if not store[i]:
				# someone is unconnected
				sys.exit(1)
		else:
			# we're looking for a peer that isn't peered yet
			sys.exit(2)

	# must be good!
	sys.exit(0)

elif mode == '--property':
	if len(argv) != 1:
		sys.exit(3)

	store = []
	for i in root.findall('.//option'):
		if i.find('name').text == str(argv[0]):
			store.append(i.find('value').text)

	if len(store) == 1:
		print(store[0])
		sys.exit(0)
	else:			# more than one value found
		sys.exit(1)

# else:
sys.exit(3)

