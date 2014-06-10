# coding: utf-8

require 'transpec/dynamic_analyzer/rewriter'
require 'transpec/dynamic_analyzer/runtime_data'
require 'transpec/project'
require 'transpec/spec_suite'
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
    HELPER_TEMPLATE_FILE = 'transpec_analysis_helper.rb.erb'
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
        put_analysis_helper
        modify_dot_rspec
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

      spec_suite = SpecSuite.new(paths)

      spec_suite.specs.each do |spec|
        next if spec.syntax_error
        rewriter.rewrite_file!(spec)
      end
    end

    def helper_filename
      File.basename(HELPER_TEMPLATE_FILE, '.erb')
    end

    def helper_source
      erb_path = File.join(File.dirname(__FILE__), 'dynamic_analyzer', HELPER_TEMPLATE_FILE)
      erb = ERB.new(File.read(erb_path), nil)
      erb.result(binding)
    end

    def put_analysis_helper
      File.write(helper_filename, helper_source)
    end

    def modify_dot_rspec
      filename = '.rspec'
      content = "--require ./#{helper_filename}\n"
      content << File.read(filename) if File.exist?(filename)
      File.write(filename, content)
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
