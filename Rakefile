require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

YARD::Rake::YardocTask.new do |t|
  t.options = ['--private', '--protected']
  t.stats_options = ['--list-undoc']
end