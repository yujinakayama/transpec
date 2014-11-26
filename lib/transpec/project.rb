# coding: utf-8

require 'transpec/rspec_version'
require 'English'

module Transpec
  class Project
    attr_reader :path

    def initialize(path = Dir.pwd)
      @path = path
    end

    def basename
      File.basename(path)
    end

    def require_bundler?
      File.exist?(gemfile_lock_path)
    end

    def depend_on_rspec_rails?
      return @depend_on_rspec_rails if instance_variable_defined?(:@depend_on_rspec_rails)
      return @depend_on_rspec_rails = false unless require_bundler?

      require 'bundler'
      gemfile_lock_content = File.read(gemfile_lock_path)
      lockfile = Bundler::LockfileParser.new(gemfile_lock_content)
      @depend_on_rspec_rails = lockfile.specs.any? { |gem| gem.name == 'rspec-rails' }
    end

    def rspec_version
      @rspec_version ||= RSpecVersion.new(fetch_rspec_version)
    end

    def with_bundler_clean_env
      if defined?(Bundler) && require_bundler?
        Bundler.with_clean_env do
          # Bundler.with_clean_env cleans environment variables
          # which are set after bundler is loaded.
          yield
        end
      else
        yield
      end
    end

    private

    def gemfile_lock_path
      @gemfile_lock_path ||= File.join(path, 'Gemfile.lock')
    end

    def fetch_rspec_version
      command = 'rspec --version'
      command = 'bundle exec ' + command if require_bundler?

      output = nil

      Dir.chdir(path) do
        with_bundler_clean_env do
          IO.popen(command) do |io|
            output = io.read
          end
        end
      end

      fail 'Failed checking RSpec version.' if output.nil? || $CHILD_STATUS.exitstatus != 0

      output.chomp
    end
  end
end
