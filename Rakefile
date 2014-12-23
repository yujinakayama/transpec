require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rspec/core/version'

RuboCop::RakeTask.new(:style)

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

task default: %w(spec style readme)

ci_tasks = %w(spec)

if RUBY_ENGINE != 'jruby' && RSpec::Core::Version::STRING.start_with?('2.14')
  ci_tasks.concat(%w(style readme:check test:all))
end

task ci: ci_tasks
