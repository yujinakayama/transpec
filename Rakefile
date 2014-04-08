require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
Rubocop::RakeTask.new(:style)

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

task default: %w(spec style readme)

ci_tasks = %w(spec style readme:check test:all)
ci_tasks << 'test:all' unless RUBY_ENGINE == 'jruby'
task ci: ci_tasks
