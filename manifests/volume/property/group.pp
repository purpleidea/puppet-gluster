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

# NOTE: The most well known group is 'virt', and is a collection of properties.
# NOTE: This type is particularly useful, because if you've set a certain group
# for your volume, and your package updates the group properties, then this can
# notice those changes and keep your volume in sync with the latest properties!
# NOTE: This intentionally conflicts with properties that are defined manually.
# NOTE: this does the equivalent of: gluster volume set <VOLNAME> group <GROUP>

define gluster::volume::property::group(
	$vip = '',		# vip of the cluster (optional but recommended)
) {
	include gluster::xml
	include gluster::vardir
	include gluster::volume::property::group::data

	#$vardir = $::gluster::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::gluster::vardir::module_vardir, '\/$', '')

	$split = split($name, '#')	# do some $name parsing
	$volume = $split[0]		# volume name
	$group = $split[1]		# group name

	if ! ( "${volume}#${group}" == "${name}" ) {
		fail('The property $name must match a $volume#$group pattern.')
	}

	$groups = split($gluster_property_groups, ',')	# fact

	if ! ("${group}" in $groups) {

		# check a fact to see if the directory is built yet... this
		# prevents weird corner cases where this module is added to
		# a new machine which is already built, except doesn't have
		# the custom group data installed yet. if we fail, we won't
		# be able to install it, so we don't fail, we warn instead!
		if "${gluster_property_groups_ready}" == 'true' {
			warning("The group named '${group}' is not available.")
		} else {
			notice("The group '${group}' might not be built yet.")
		}
	} else {
		# read the fact that comes from the data in: /var/lib/glusterd/groups/*
		$group_data_string = getvar("gluster_property_group_${group}")	# fact!
		# each element in this list is a key=value string
		$group_data_list = split("${group_data_string}", ',')
		# split into the correct hash to create all the properties
		$group_data_yaml = inline_template("<%= @group_data_list.inject(Hash.new) { |h,i| { '${volume}#'+((i.split('=').length == 2) ? i.split('=')[0] : '') => {'value' => ((i.split('=').length == 2) ? i.split('=')[1] : '')} }.merge(h) }.to_yaml %>")
		# build into a hash
		$group_data_hash = parseyaml($group_data_yaml)
		# pass through the vip
		$group_data_defaults = {'vip' => "${vip}"}
		# create the properties
		create_resources('gluster::volume::property', $group_data_hash, $group_data_defaults)
	}
}

# vim: ts=8
