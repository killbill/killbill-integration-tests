# frozen_string_literal: true

#
# Copyright 2010-2013 Ning, Inc.
#
# Ning licenses this file to you under the Apache License, version 2.0
# (the "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#

$LOAD_PATH.unshift('./')
require 'killbill-integration-tests/version'

Gem::Specification.new do |s|
  s.name        = 'killbill-integration-tests'
  s.version     = KillBillIntegrationTests::Version.to_s
  s.summary     = 'Kill Bill test suite.'
  s.description = 'A test suite against a running instance of Kill Bill.'

  s.required_ruby_version = '>= 2.4'

  s.license = 'Apache License (2.0)'

  s.author   = 'Killbill core team'
  s.email    = 'killbilling-users@googlegroups.com'
  s.homepage = 'http://www.killbilling.org'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = %w[lib killbill-integration-tests]

  s.rdoc_options << '--exclude' << '.'

  s.add_development_dependency 'ci_reporter_test_unit', '~> 1.0.1'
  s.add_development_dependency 'concurrent-ruby', '~> 1.0.0.pre1'
  s.add_development_dependency 'faker', '~> 1.5'
  s.add_development_dependency 'mail', '~> 2.8.0.rc1'
  s.add_development_dependency 'midi-smtp-server', '~> 2.3.3'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rubocop', '~> 0.88.0'
  s.add_development_dependency 'test-unit', '~> 3.3.6'
  s.add_development_dependency 'thread', '0.2.2'
  s.add_development_dependency 'toxiproxy', '~> 2.0.1'
  s.add_development_dependency 'tzinfo-data', '~> 1.2021'
end
