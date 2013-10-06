# coding: utf-8

module Transpec
  module Git
    GIT = 'git'

    module_function

    def command_available?
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
        git_path = File.join(path, GIT)
        File.exists?(git_path)
      end
    end

    def inside_of_repository?
      fail '`git` command is not available' unless command_available?
      system("#{GIT} rev-parse --is-inside-work-tree > /dev/null 2> /dev/null")
    end

    def clean?
      fail 'The current working directory is not a Git repository' unless inside_of_repository?
      `#{GIT} status --porcelain`.empty?
    end
  end
end
