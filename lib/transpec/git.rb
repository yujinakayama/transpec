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
      system("#{GIT} rev-parse --is-inside-work-tree > /dev/null 2> /dev/null")
    end

    def clean?
      `#{GIT} status --porcelain`.empty?
    end
  end
end
