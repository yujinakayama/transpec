# coding: utf-8

class TranspecTest
  include FileUtils # This is Rake's one.

  attr_reader :url, :ref, :bundler_args

  def self.base_dir
    @base_dir ||= begin
      base_dir = File.join('tmp', 'projects')

      unless Dir.exist?(base_dir)
        require 'fileutils'
        FileUtils.mkdir_p(base_dir)
      end

      base_dir
    end
  end

  def initialize(url, ref = nil, bundler_args = [])
    @url = url
    @ref = ref
    @bundler_args = bundler_args

    # On Travis CI, reuse system gems to speed up build.
    @bundler_args.concat(%w(--path vendor/bundle)) unless ENV['TRAVIS']
  end

  def name
    @name ||= File.basename(url, '.git')
  end

  def project_dir
    @project_dir ||= File.join(self.class.base_dir, name)
  end

  def run
    require 'transpec'

    puts " Testing on #{name} Project ".center(80, '=')

    prepare_git_repo

    in_project_dir do
      with_clean_bundler_env do
        sh 'bundle', 'install', *bundler_args
        sh File.join(Transpec.root, 'bin', 'transpec'), '--force'
        sh 'bundle exec rspec'
      end
    end
  end

  private

  def prepare_git_repo
    if Dir.exist?(project_dir)
      if current_ref == ref
        git_reset_hard
      else
        require 'fileutils'
        FileUtils.rm_rf(project_dir)
        git_clone
      end
    else
      git_clone
    end
  end

  def in_project_dir(&block)
    Dir.chdir(project_dir, &block)
  end

  def current_ref
    in_project_dir do
      `git describe --all`.chomp.sub(/\Aheads\//, '')
    end
  end

  def git_reset_hard
    in_project_dir do
      sh 'git reset --hard'
    end
  end

  def git_clone
    Dir.chdir(self.class.base_dir) do
      # Disabling checkout here to suppress "detached HEAD" warning.
      sh "git clone --no-checkout --depth 1 --branch #{ref} #{url}"
    end

    in_project_dir do
      sh "git checkout --quiet #{ref}"
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
    # Disable Coveralls.
    ENV['CI'] = ENV['JENKINS_URL'] = ENV['COVERALLS_RUN_LOCALLY'] = nil
  end
end

namespace :test do
  tests = [
    TranspecTest.new('https://github.com/sferik/twitter.git', 'v4.1.0'),
    TranspecTest.new('https://github.com/yujinakayama/guard.git', 'transpec', %w(--without development)), # rubocop:disable LineLength
    TranspecTest.new('https://github.com/yujinakayama/mail.git', 'transpec')
  ]

  desc 'Test Transpec on all projects'
  task all: tests.map(&:name)

  tests.each do |test|
    desc "Test Transpec on #{test.name.capitalize} project"
    task test.name do
      test.run
    end
  end
end
