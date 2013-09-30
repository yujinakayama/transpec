# coding: utf-8

namespace :test do
  projects = [
    [:twitter, 'https://github.com/sferik/twitter.git',     'v4.1.0'],
    [:guard,   'https://github.com/yujinakayama/guard.git', 'transpec', %w(--without development)],
    [:mail,    'https://github.com/yujinakayama/mail.git', 'transpec']
  ]

  desc 'Test Transpec on all projects'
  task all: projects.map(&:first)

  projects.each do |name, url, ref, bundler_args|
    desc "Test Transpec on #{name.to_s.capitalize} project"
    task name do
      tmpdir = File.join('tmp', 'projects')

      unless Dir.exist?(tmpdir)
        require 'fileutils'
        FileUtils.mkdir_p(tmpdir)
      end

      Dir.chdir(tmpdir) do
        test_on_project(name.to_s.capitalize, url, ref, bundler_args)
      end
    end
  end

  def test_on_project(name, url, ref, bundler_args = nil)
    require 'transpec'

    puts " Testing on #{name} Project ".center(80, '=')

    repo_dir = prepare_git_repo(url, ref)

    bundler_args ||= []
    # On Travis CI, reuse system gems to speed up build.
    bundler_args.concat(%w(--path vendor/bundle)) unless ENV['TRAVIS']

    Dir.chdir(repo_dir) do
      with_clean_bundler_env do
        sh 'bundle', 'install', *bundler_args
        sh File.join(Transpec.root, 'bin', 'transpec'), '--force'
        sh 'bundle exec rspec'
      end
    end
  end

  def prepare_git_repo(url, ref)
    repo_dir = File.basename(url, '.git')

    needs_clone = false

    if Dir.exist?(repo_dir)
      current_ref = nil

      Dir.chdir(repo_dir) do
        current_ref = `git describe --all`.chomp.sub(/\Aheads\//, '')
      end

      if current_ref == ref
        Dir.chdir(repo_dir) do
          sh 'git reset --hard'
        end
      else
        require 'fileutils'
        FileUtils.rm_rf(repo_dir)
        needs_clone = true
      end
    else
      needs_clone = true
    end

    if needs_clone
      # Disabling checkout here to suppress "detached HEAD" warning.
      sh "git clone --no-checkout --depth 1 --branch #{ref} #{url}"

      Dir.chdir(repo_dir) do
        sh "git checkout --quiet #{ref}"
      end
    end

    repo_dir
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
