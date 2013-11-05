# coding: utf-8

require 'transpec/rspec_version'

module Transpec
  class Project
    attr_reader :path

    def initialize(path = Dir.pwd)
      @path = path
    end

    def basename
      File.basename(@path)
    end

    def require_bundler?
      gemfile_path = File.join(@path, 'Gemfile')
      File.exist?(gemfile_path)
    end

    def rspec_version
      @rspec_version ||= begin
        command = 'rspec --version'
        command = 'bundle exec ' + command if require_bundler?

        version_string = nil

        Dir.chdir(@path) do
          with_bundler_clean_env { version_string = `#{command}`.chomp }
        end

        RSpecVersion.new(version_string)
      end
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
  end
end
