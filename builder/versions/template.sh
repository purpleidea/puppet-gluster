#!/bin/bash

# to use this script, from its parent dir, run: ./versions/<script>.sh <target>
# you'll want to edit the below bash variables to match your use cases :)
# eg: ./versions/centos-6.sh upload
# to make your own base image and upload it to your own server somewhere.

VERSION='centos-6'		# pick from the output of virt-builder -l
SERVER='user@host.example.org'	# connect over ssh (add your public key first)
REMOTE_PATH='public_html/vagrant'	# make a $VERSION directory in this dir

make VERSION=$VERSION SERVER=$SERVER REMOTE_PATH=$REMOTE_PATH $@

