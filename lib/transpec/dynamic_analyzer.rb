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
require 'English'

module Transpec
  class DynamicAnalyzer
    ANALYSIS_METHOD = 'transpec_analysis'
    HELPER_FILE = 'transpec_analysis_helper.rb'
    RESULT_FILE = 'transpec_analysis_result.json'
    HELPER_SOURCE = <<-END
      require 'pathname'

      module TranspecAnalysis
        @base_path = Dir.pwd

        def self.data
          @data ||= {}
        end

        def self.node_id(filename, begin_pos, end_pos)
          absolute_path = File.expand_path(filename)
          relative_path = Pathname.new(absolute_path).relative_path_from(base_pathname).to_s
          [relative_path, begin_pos, end_pos].join('_')
        end

        def self.base_pathname
          @base_pathname ||= Pathname.new(@base_path)
        end

        at_exit do
          # Use JSON rather than Marshal so that:
          # * Unknown third-party class information won't be serialized.
          #   (Such objects are stored as a string.)
          # * Singleton method information won't be serialized.
          #   (With Marshal.load, `singleton can't be dumped (TypeError)` will be raised.)
          require 'json'
          path = File.join(@base_path, '#{RESULT_FILE}')
          File.open(path, 'w') do |file|
            JSON.dump(data, file)
          end
        end
      end

      def #{ANALYSIS_METHOD}(object, context, analysis_codes, filename, begin_pos, end_pos)
        pair_array = analysis_codes.map do |key, (target_type, code)|
          target = case target_type
                   when :object  then object
                   when :context then context
                   end

          eval_data = {}

          begin
            eval_data[:result] = target.instance_eval(code)
          rescue Exception => error
            eval_data[:error] = error
          end

          [key, eval_data]
        end

        object_data = Hash[pair_array]

        id = TranspecAnalysis.node_id(filename, begin_pos, end_pos)
        TranspecAnalysis.data[id] = object_data

        object
      end
    END

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
        rewriter = Rewriter.new

        FileFinder.find(paths).each do |file_path|
          begin
            rewriter.rewrite_file!(file_path)
          rescue Parser::SyntaxError # rubocop:disable HandleExceptions
            # Syntax errors will be reported in CLI with Converter.
          end
        end

        File.write(HELPER_FILE, HELPER_SOURCE)

        run_rspec(paths)

        File.open(RESULT_FILE) do |file|
          RuntimeData.load(file)
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
  end
end
