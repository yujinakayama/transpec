# coding: utf-8

class TranspecTest
  include FileUtils # This is Rake's one.

  attr_reader :url, :ref, :bundler_args

  def self.base_dir
    @base_dir ||= begin
      unless Dir.exist?(base_dir_path)
        require 'fileutils'
        FileUtils.mkdir_p(base_dir_path)
      end

      base_dir_path
    end
  end

  def self.base_dir_path
    @base_dir_path = File.join('tmp', 'tests')
  end

  def initialize(url, ref = nil, bundler_args = [])
    @url = url
    @ref = ref
    @bundler_args = bundler_args
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
    prepare_project
    run_test(%w(--force))
  end

  private

  def prepare_project
    if url.start_with?('/')
      prepare_with_local_dir
    else
      prepare_with_git_repo
    end
  end

  def prepare_with_local_dir
    if Dir.exist?(project_dir)
      require 'fileutils'
      FileUtils.rm_rf(project_dir)
    end

    Dir.mkdir(project_dir)

    Dir.chdir(url) do
      Dir.new('.').each do |entry|
        next if ['.', '..', 'tmp'].include?(entry)
        FileUtils.cp_r(entry, project_dir)
      end
    end

    bundle_install
  end

  def prepare_with_git_repo
    if Dir.exist?(project_dir)
      git_checkout(ref) unless current_ref == ref
      git_checkout('.')
    else
      git_clone
      bundle_install
    end
  end

  def run_test(transpec_args = [])
    in_project_dir do
      with_clean_bundler_env do
        sh File.join(Transpec.root, 'bin', 'transpec'), *transpec_args
        sh 'bundle exec rspec'
      end
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

  def git_checkout(*args)
    in_project_dir do
      sh 'git', 'checkout', *args
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

  def bundle_install
    in_project_dir do
      with_clean_bundler_env do
        sh 'bundle', 'install', *bundler_args
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
    # Disable Coveralls.
    ENV['CI'] = ENV['JENKINS_URL'] = ENV['COVERALLS_RUN_LOCALLY'] = nil

    ENV['TRANSPEC_TEST'] = 'true'
  end
end
