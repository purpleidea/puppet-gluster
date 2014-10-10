source 'https://rubygems.org'

puppet_version = ENV.key?('PUPPET_VERSION') ? "= #{ENV['PUPPET_VERSION']}" : ['>= 3.0']

gem 'rake'
gem 'puppet', puppet_version
gem 'puppet-lint'	# style things, eg: tabs vs. spaces
gem 'rspec-puppet', :git => 'https://github.com/rodjek/rspec-puppet.git'
gem 'puppet-syntax'	# syntax checking
gem 'puppetlabs_spec_helper'

