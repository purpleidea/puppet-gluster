# Makefile for building Vagrant (libvirt) base image "boxes" for Puppet-Gluster
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

# NOTE: if you change any of the values in this file (such as SIZE or --install
# arguments) make won't notice the change, you'll have to manually clean first.

.PHONY: all builder convert box local upload clean
.SILENT:

# TODO: build base image for virt-builder from iso instead of using templates

# virt-builder os-version
VERSION = centos-6
BOX = $(VERSION).box
SIZE = 40
#OUTPUT = /tmp/gluster
#OUTPUT := $(shell pwd)
OUTPUT := $(shell echo ~/tmp/builder/$(VERSION))
SERVER = 'user@host.example.org'
REMOTE_PATH = 'public_html/vagrant'

all: box

#
#	aliases
#
builder: $(OUTPUT)/builder.img
convert: $(OUTPUT)/box.img
box: $(OUTPUT)/$(BOX)
local: $(OUTPUT)/SHA256SUMS.asc

#
#	clean
#
# delete created files
clean:
	@echo Running clean...
	# TODO: technically, the 'true' should check if all the files are rm-ed
	rm $(OUTPUT)/{{builder,box}.img,metadata.json,$(BOX),SHA256SUMS{,.asc}} || true

#
#	virt-builder
#
# build image with virt-builder
# NOTE: some of this system prep is based on the vagrant-libvirt scripts
# TODO: install: ruby ruby-devel make gcc rubygems ?
$(OUTPUT)/builder.img: files/*
	@echo Running virt-builder...
	[ -d $(OUTPUT) ] || mkdir -p $(OUTPUT)/	# ensure path is present first!
	virt-builder $(VERSION) \
	--output $(OUTPUT)/builder.img \
	--format qcow2 \
	--size $(SIZE)G \
	--install rsync,nfs-utils,sudo,openssh-server,openssh-clients \
	--install screen,vim-enhanced,git,wget,file,man,tree,nmap,tcpdump,htop,lsof,telnet,mlocate,bind-utils,koan,iftop,yum-utils,nc \
	--root-password file:files/password \
	--upload files/epel-release-6-8.noarch.rpm:/root/epel-release-6-8.noarch.rpm \
	--upload files/puppetlabs-release-el-6.noarch.rpm:/root/puppetlabs-release-el-6.noarch.rpm \
	--run-command 'yum install -y /root/epel-release-6-8.noarch.rpm && rm -f /root/epel-release-6-8.noarch.rpm' \
	--run-command 'yum install -y bash-completion moreutils' \
	--run-command 'yum install -y /root/puppetlabs-release-el-6.noarch.rpm && rm -f /root/puppetlabs-release-el-6.noarch.rpm' \
	--run-command 'yum install -y puppet' \
	--run-command 'yum update -y' \
	--run files/user.sh \
	--run files/ssh.sh \
	--run files/network.sh \
	--run files/cleanup.sh

	# boot machine once to run the selinux relabelling, see:
	# https://www.redhat.com/archives/libguestfs/2014-January/msg00183.html
	# https://github.com/libguestfs/libguestfs/commit/20a4bfde9628cfeb8bea441cab7dcc94843b34e3
	qemu-system-x86_64 -machine accel=kvm:tcg -cpu host -m 512 -drive file=$(OUTPUT)/builder.img,format=qcow2,if=virtio -no-reboot -serial stdio -nographic || (rm $(OUTPUT)/builder.img; false)
	reset	# TODO: qemu-system-x86_64 borks the terminal :(

#
#	convert
#
# workaround sparse qcow2 images bug
# thread: https://www.redhat.com/archives/libguestfs/2014-January/msg00008.html
$(OUTPUT)/box.img: $(OUTPUT)/builder.img
	@echo Running convert...
	qemu-img convert -O qcow2 $(OUTPUT)/builder.img $(OUTPUT)/box.img

#
#	metadata.json
#
$(OUTPUT)/metadata.json:
	@echo Running templater...
	[ -d $(OUTPUT) ] || mkdir -p $(OUTPUT)/	# ensure path is present first!
	echo '{"provider": "libvirt", "format": "qcow2", "virtual_size": $(SIZE)}' > $(OUTPUT)/metadata.json
	echo '' >> $(OUTPUT)/metadata.json	# newline

#
#	tar
#
# create custom box
# format at: https://github.com/pradels/vagrant-libvirt/tree/master/example_box
$(OUTPUT)/$(BOX): Vagrantfile $(OUTPUT)/metadata.json $(OUTPUT)/box.img
	@echo Running tar...
	tar -cvzf $(OUTPUT)/$(BOX) ./Vagrantfile --directory=$(OUTPUT)/ ./metadata.json ./box.img

#
#	sha256sum
#
$(OUTPUT)/SHA256SUMS: $(OUTPUT)/$(BOX)
	@echo Running sha256sum...
	cd $(OUTPUT) && sha256sum $(BOX) > SHA256SUMS; cd -

#
#	gpg
#
$(OUTPUT)/SHA256SUMS.asc: $(OUTPUT)/SHA256SUMS
	@echo Running gpg...
	# the --yes forces an overwrite of the SHA256SUMS.asc if necessary
	gpg2 --yes --clearsign $(OUTPUT)/SHA256SUMS

#
#	upload
#
# upload to public server
# NOTE: user downloads while file uploads are in progress don't cause problems!
upload: $(OUTPUT)/$(BOX) $(OUTPUT)/SHA256SUMS $(OUTPUT)/SHA256SUMS.asc
	if [ "`cat $(OUTPUT)/SHA256SUMS`" != "`ssh $(SERVER) 'cd $(REMOTE_PATH)/$(VERSION)/ && sha256sum $(BOX)'`" ]; then \
		echo Running upload...; \
		scp -p $(OUTPUT)/{$(BOX),SHA256SUMS{,.asc}} $(SERVER):$(REMOTE_PATH)/$(VERSION)/; \
	fi
# this method works too, but always hits the server on every make call
#upload:
#ifeq ($(shell cat $(OUTPUT)/SHA256SUMS), $(shell ssh $(SERVER) 'cd $(REMOTE_PATH)/ && sha256sum $(BOX)'))
#	@echo true
#else
#	@echo false
#endif

