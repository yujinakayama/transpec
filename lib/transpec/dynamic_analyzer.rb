# coding: utf-8

require 'transpec/dynamic_analyzer/rewriter'
require 'transpec/dynamic_analyzer/runtime_data'
require 'transpec/file_finder'
require 'transpec/project'
require 'tmpdir'
require 'find'
require 'pathname'
require 'fileutils'
require 'shellwords'
require 'erb'
require 'English'

module Transpec
  class DynamicAnalyzer
    ANALYSIS_METHOD = 'transpec_analyze'
    HELPER_FILE = 'transpec_analysis_helper.rb'
    RESULT_FILE = 'transpec_analysis_result.json'

    attr_reader :project, :rspec_command, :silent
    alias_method :silent?, :silent

    def initialize(options = {})
      @project = options[:project] || Project.new
      @rspec_command = options[:rspec_command] || default_rspec_command
      @silent = options[:silent] || false

      if block_given?
        in_copied_project do
          yield self
        end
      end
    end

    def default_rspec_command
      if project.require_bundler?
        'bundle exec rspec'
      else
        'rspec'
      end
    end

    def analyze(paths = [])
      in_copied_project do
        rewrite_specs(paths)

        File.write(HELPER_FILE, helper_source)

        run_rspec(paths)

        begin
          File.open(RESULT_FILE) do |file|
            RuntimeData.load(file)
          end
        rescue
          raise AnalysisError
        end
      end
    end

    def in_copied_project
      return yield if @in_copied_project

      @in_copied_project = true

      Dir.mktmpdir do |tmpdir|
        copy_recursively(project.path, tmpdir)
        copied_project_path = File.join(tmpdir, project.basename)
        Dir.chdir(copied_project_path) do
          yield
        end
      end
    ensure
      @in_copied_project = false
    end

    def run_rspec(paths)
      project.with_bundler_clean_env do
        ENV['SPEC_OPTS'] = ['-r', "./#{HELPER_FILE}"].shelljoin

        command = "#{rspec_command} #{paths.shelljoin}"

        if silent?
          `#{command} 2> /dev/null`
        else
          system(command)
        end
      end
    end

    def copy_recursively(source_root, destination_root)
      source_root = File.expand_path(source_root)
      source_root_pathname = Pathname.new(source_root)

      destination_root = File.expand_path(destination_root)
      if File.directory?(destination_root)
        destination_root = File.join(destination_root, File.basename(source_root))
      end

      Find.find(source_root) do |source_path|
        relative_path = Pathname.new(source_path).relative_path_from(source_root_pathname).to_s
        destination_path = File.join(destination_root, relative_path)
        copy(source_path, destination_path)
      end
    end

    private

    def rewrite_specs(paths)
      rewriter = Rewriter.new

      FileFinder.find(paths).each do |file_path|
        begin
          rewriter.rewrite_file!(file_path)
        rescue Parser::SyntaxError # rubocop:disable HandleExceptions
          # Syntax errors will be reported in CLI with Converter.
        end
      end
    end

    def helper_source
      erb_path = File.join(File.dirname(__FILE__), 'dynamic_analyzer', 'helper.rb.erb')
      erb = ERB.new(File.read(erb_path), nil)
      erb.result(binding)
    end

    def copy(source, destination)
      if File.symlink?(source)
        File.symlink(File.readlink(source), destination)
      elsif File.directory?(source)
        FileUtils.mkdir_p(destination)
      elsif File.file?(source)
        FileUtils.copy_file(source, destination)
      end

      copy_permission(source, destination) if File.exist?(destination)
    end

    def copy_permission(source, destination)
      source_mode = File.lstat(source).mode
      begin
        File.lchmod(source_mode, destination)
      rescue NotImplementedError, Errno::ENOSYS
        # Should not change mode of symlink's destination.
        File.chmod(source_mode, destination) unless File.symlink?(destination)
      end
    end

    class AnalysisError < StandardError; end
  end
end
