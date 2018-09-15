require 'bundler/gem_tasks'
require 'rspec/core/version'

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:style)

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

task default: %w(spec style readme)
