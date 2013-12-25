require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
Rubocop::RakeTask.new(:style)

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

task default: [:spec, :style, :readme]

travis_tasks = [:spec]
travis_tasks << :style unless RUBY_VERSION.start_with?('1.9')
travis_tasks.concat(['readme:check', 'test:all'])
task travis: travis_tasks
