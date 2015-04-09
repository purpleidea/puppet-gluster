# *puppet-gluster*: a puppet module for GlusterFS

[![Build Status](https://secure.travis-ci.org/purpleidea/puppet-gluster.png)](http://travis-ci.org/purpleidea/puppet-gluster)

## Documentation:
Please see: [DOCUMENTATION.md](DOCUMENTATION.md) or [PDF](https://pdfdoc-purpleidea.rhcloud.com/pdf/https://github.com/purpleidea/puppet-gluster/blob/master/DOCUMENTATION.md).

## Installation:
Please read the [INSTALL](INSTALL) file for instructions on getting this installed.

## Examples:
Please look in the [examples/](examples/) folder for usage. If none exist, please contribute one!

## Module specific notes:
* This is _the_ puppet module for gluster. Accept no imitations!
* All the participating nodes, need to have an identical puppet-gluster config.
* Using gluster::simple is probably the best way to try this out.
* This is easily deployed with vagrant. See the [vagrant/](vagrant/) directory!
* You can use less of the available resources, if you only want to manage some.
* You can get packages for CentOS and RHEL and other distributions from:
** http://download.gluster.org/pub/gluster/glusterfs/LATEST/
* Documentation is now available! Please report grammar and spelling bugs.

## Dependencies:
* [puppetlabs-stdlib](https://github.com/puppetlabs/puppetlabs-stdlib) (required)
* [puppet-module-data](https://github.com/ripienaar/puppet-module-data/) (optional, puppet >= 3.0.0)
* my [puppet-common](https://github.com/purpleidea/puppet-common) module (optional)
* my [puppet-shorewall](https://github.com/purpleidea/puppet-shorewall) module (optional)
* my [puppet-keepalived](https://github.com/purpleidea/puppet-keepalived) module (optional)
* my [puppet-puppet](https://github.com/purpleidea/puppet-puppet) module (optional)
* my [puppet-yum](https://github.com/purpleidea/puppet-yum) module (optional)
* gluster packages (see above notes)
* pandoc (for building a pdf of the documentation)

## Patches:
This code may be a work in progress. The interfaces may change without notice.
Patches are welcome, but please be patient. They are best received by email.
Please ping me if you have big changes in mind, before you write a giant patch.

##

Happy hacking!

