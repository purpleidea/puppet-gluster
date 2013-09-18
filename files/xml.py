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
#	$ gluster peer status --xml | ./xml.py connected <PEER1> <PEER2> <PEERn>
#	<BOOL>

# 	EXAMPLE:
#	$ gluster volume info --xml <VOLNAME> | ./xml.py property --key <KEY>
#	<VALUE>

# 	EXAMPLE:
#	$ gluster volume status --xml [<VOLNAME>] | ./xml.py port --volume <VOLUME> --host <HOST> --path <PATH>
#	<PORT>

# 	EXAMPLE:
#	$ gluster volume status --xml [<VOLNAME>] | ./xml.py ports [--volume <VOLUME>] [--host <HOST>]
#	<PORT1>[,<PORT2>[,<PORTn>]]

import sys
import argparse
import lxml.etree as etree

parser = argparse.ArgumentParser(description='gluster xml parsing tools')
#parser.add_argument('--debug', dest='debug', action='store_true', default=False)
subparsers = parser.add_subparsers(dest='mode')

#
#	'connected' parser
#
parser_connected = subparsers.add_parser('connected')
parser_connected.add_argument('peers', type=str, nargs='*', action='store')

#
#	'property' parser
#
parser_property = subparsers.add_parser('property')
parser_property.add_argument('--key', dest='key', action='store')

#
#	'port' parser
#
parser_port = subparsers.add_parser('port')
parser_port.add_argument('--volume', dest='volume', action='store', required=True)
parser_port.add_argument('--host', dest='host', action='store', required=True)
parser_port.add_argument('--path', dest='path', action='store', required=True)

#
#	'ports' parser
#
parser_ports = subparsers.add_parser('ports')
parser_ports.add_argument('--volume', dest='volume', action='store', required=False)
parser_ports.add_argument('--host', dest='host', action='store', required=False)

#
#	final setup...
#
args = parser.parse_args()
tree = etree.parse(sys.stdin)
root = tree.getroot()

# are all the hostnames in argv connected ?
if args.mode == 'connected':
	store = {}
	peers = args.peers

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

elif args.mode == 'property':
	store = []
	for i in root.findall('.//option'):
		if str(i.find('name').text) == args.key:
			store.append(i.find('value').text)

	if len(store) == 1:
		print(store[0])
		sys.exit(0)
	else:			# more than one value found
		sys.exit(1)

elif args.mode == 'port':
	port = 0
	found = False
	#print args.volume  # volume
	#print args.host  # hostname
	#print args.path  # path
	for i in root.findall('.//volumes'):
		for j in i.findall('.//volume'):
			v = str(j.find('volName').text)
			#print v
			for k in j.findall('.//node'):
				h = str(k.find('hostname').text)
				p = str(k.find('path').text)
				#print h, p
				#if v == args.volume and h == args.host and p == args.path:
				if (v, h, p) == (args.volume, args.host, args.path):
					if found:
						# we have already found a match.
						# there's a bug somewhere...
						sys.exit(2)
					found = True
					port = int(k.find('port').text)

	if found and port > 0:
		print(port)
		sys.exit(0)
	else:		   # no value found
		sys.exit(1)

# list all the ports used by one volume
elif args.mode == 'ports':
	ports = []
	found = False
	#print args.volume  # volume (optional)
	for i in root.findall('.//volumes'):
		for j in i.findall('.//volume'):
			v = str(j.find('volName').text)
			#print v
			# if no volume is specified, we use all of them...
			if args.volume is None or args.volume == v:
				for k in j.findall('.//node'):
					h = str(k.find('hostname').text)
					p = str(k.find('path').text)
					#print h, p
					if args.host is None or args.host == h:
						try:
							ports.append(int(k.find('port').text))
							found = True
						except ValueError, e:
							pass

	if found and len(ports) > 0:
		# NOTE: you may get duplicates if you lookup multiple hosts...
		# here we remove any duplicates and convert each int to strings
		print(','.join([str(x) for x in list(set(ports))]))
		sys.exit(0)
	else:		   # no value found
		sys.exit(1)

# else:
sys.exit(3)

# vim: ts=8
