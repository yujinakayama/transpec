# coding: utf-8

module Transpec
  module Git
    GIT = 'git'
    COMMIT_MESSAGE_FILE_PATH = File.join('.git', 'COMMIT_EDITMSG')

    module_function

    def command_available?
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
        git_path = File.join(path, GIT)
        File.exist?(git_path)
      end
    end

    def inside_of_repository?
      fail '`git` command is not available' unless command_available?
      system("#{GIT} rev-parse --is-inside-work-tree > /dev/null 2> /dev/null")
    end

    def clean?
      fail_unless_inside_of_repository
      `#{GIT} status --porcelain`.empty?
    end

    def repository_root
      fail_unless_inside_of_repository
      `#{GIT} rev-parse --show-toplevel`.chomp
    end

    def write_commit_message(message)
      fail_unless_inside_of_repository
      file_path = File.join(repository_root, COMMIT_MESSAGE_FILE_PATH)
      File.write(file_path, message)
    end

    def fail_unless_inside_of_repository
      fail 'The current working directory is not a Git repository' unless inside_of_repository?
    end
  end
end
