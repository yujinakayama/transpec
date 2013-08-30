require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
Rubocop::RakeTask.new(:style)

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

desc 'Generate README.md'
task :readme do
  require 'erb'
  require 'transpec/cli'

  gem_specification = Gem::Specification.load('transpec.gemspec')
  rspec_dependency = gem_specification.dependencies.find { |d| d.name == 'rspec' }
  rspec_requirement = rspec_dependency.requirement
  rspec_version = rspec_requirement.requirements.first.find { |r| r.is_a?(Gem::Version) }

  erb = ERB.new(File.read('README.md.erb'), nil, '-')
  content = erb.result(binding)
  File.write('README.md', content)
end

task :abort_unless_latest_readme_is_committed => :readme do
  unless Transpec::Git.clean?
    warn 'Commit README.md before release.'
    exit 1
  end
end

Rake::Task[:release].enhance([:abort_unless_latest_readme_is_committed])

namespace :test do
  desc 'Test Transpec on some other projects'
  task :other_projects do
    projects = [
      ['Twitter', 'https://github.com/sferik/twitter.git', 'v4.1.0'],
      ['Guard',   'https://github.com/guard/guard.git',    'v1.8.1']
    ]

    require 'tmpdir'

    Dir.chdir(Dir.mktmpdir) do
      projects.each do |project|
        test_on_project(*project)
      end
    end
  end

  def test_on_project(name, url, ref)
    require 'transpec'

    puts " Testing on #{name} Project ".center(80, '=')

    # Disabling checkout here to suppress "detached HEAD" warning.
    sh "git clone --no-checkout --depth 1 --branch #{ref} #{url}"
    
    repo_dir = File.basename(url, '.git')

    Dir.chdir(repo_dir) do
      sh "git checkout --quiet #{ref}"
      with_clean_bundler_env do
        sh 'bundle install'
        sh File.join(Transpec.root, 'bin', 'transpec')
        sh 'rspec'
      end
    end
  end

  def with_clean_bundler_env
    if defined?(Bundler)
      Bundler.with_clean_env do
        # Bundler.with_clean_env cleans environment variables
        # which are set after bundler is loaded.
        prepare_env
        yield
      end
    else
      prepare_env
      yield
    end
  end

  def prepare_env
    # Disable Coveralls in other projects.
    ENV['CI'] = ENV['JENKINS_URL'] = ENV['COVERALLS_RUN_LOCALLY'] = nil
  end
end

task default: [:spec, :style, :readme]
