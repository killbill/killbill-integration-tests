#!/usr/bin/env rake

# Install tasks to build and release the plugin
require 'bundler/setup'
require 'rake'
require 'rake/testtask'

Bundler::GemHelper.install_tasks


namespace :test do
  Rake::TestTask.new do |t|
    t.libs << "killbill-integration-tests"
    t.test_files = FileList['killbill-integration-tests/core/test*.rb']
    t.verbose = true
  end
end


# Run tests by default
task :default => 'nothing'
