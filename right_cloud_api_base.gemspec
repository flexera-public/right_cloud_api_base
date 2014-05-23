#--  -*- mode: ruby; encoding: utf-8 -*-
# Copyright (c) 2013 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'rubygems'
require File.expand_path(File.join(File.dirname(__FILE__), 'lib/right_cloud_api_base_version'))

Gem::Specification.new do |spec|
  spec.name             = 'right_cloud_api_base'
  spec.version          = RightScale::CloudApi::VERSION::STRING
  spec.authors          = ['RightScale, Inc.']
  spec.email            = 'support@rightscale.com'
  spec.summary          = 'The gem provides base Query and REST API management functionalities for ' +
                          'Amazon, OpenStack, Rackspace, CloudStack, etc cloud services'
  spec.rdoc_options     = ['--main', 'README.md', '--title', '']
  spec.extra_rdoc_files = ['README.md']
  spec.require_path     = 'lib'
  spec.required_ruby_version = '>= 1.8.7'

  spec.add_dependency 'json',                  '>= 1.0.0'
  spec.add_dependency 'ruby-hmac',             '>= 0.4.0'
  spec.add_dependency 'libxml-ruby',           '>= 1.0.0'
  spec.add_dependency 'net-http-persistent',   '>= 2.9.0'

  spec.add_dependency 'redcarpet', (RUBY_VERSION < '1.9') ? '= 2.3.0' : '>= 3.0.0'

  spec.add_development_dependency 'rspec',     '>= 2.14.0'
  spec.add_development_dependency 'rake'

  spec.description = <<-EOF
== DESCRIPTION:

right_cloud_api_base gem.

The gem provides base Query and REST API management functionalities for
Amazon, OpenStack, Rackspace, CloudStack, etc cloud services.

EOF

  candidates      = Dir.glob('{lib,spec}/**/*') +
                    ['LICENSE', 'HISTORY', 'README.md', 'Rakefile', 'right_cloud_api_base.gemspec']
  spec.files      = candidates.sort
  spec.test_files = Dir.glob('spec/**/*')
end
