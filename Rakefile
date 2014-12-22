require 'bundler/gem_tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new(:style)

Dir['tasks/**/*.rake'].each do |path|
  load(path)
end

task default: %w(spec style readme)

ci_tasks = %w(spec)
ci_tasks.concat(%w(style readme:check test:all)) unless RUBY_ENGINE == 'jruby'
task ci: ci_tasks
