# coding: utf-8

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
