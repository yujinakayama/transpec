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
      gemfile_path = File.join(path, 'Gemfile')
      File.exist?(gemfile_path)
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
