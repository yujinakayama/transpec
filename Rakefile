require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :ci do
  desc "#{Rake::Task['spec'].comment} for CI environment"
  task :spec do
    ENV['CI'] = 'true'

    ENV['CI_REPORTS'] = 'spec/reports'
    require 'ci/reporter/rake/rspec'
    Rake::Task['ci:setup:rspec'].invoke

    Rake::Task['spec'].invoke
  end
end

desc 'Check code style with RuboCop'
task :style do
  sh('rubocop')
end

desc 'Run RSpec and RuboCop'
task all: [:spec, :style]

task default: :all
