require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/version'

if RUBY_VERSION >= '2.0'
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:style)
end

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

default_tasks = ['spec']
default_tasks << 'style' unless RUBY_VERSION.start_with?('1.')
default_tasks << 'readme'
task default: default_tasks
