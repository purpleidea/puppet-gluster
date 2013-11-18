.PHONY: all docs
.SILENT:

all: docs

docs: puppet-gluster-documentation.pdf

puppet-gluster-documentation.pdf: DOCUMENTATION.md
	pandoc DOCUMENTATION.md -o 'puppet-gluster-documentation.pdf'

