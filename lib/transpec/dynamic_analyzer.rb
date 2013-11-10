# coding: utf-8

require 'transpec/dynamic_analyzer/rewriter'
require 'transpec/dynamic_analyzer/runtime_data'
require 'transpec/file_finder'
require 'transpec/project'
require 'tmpdir'
require 'fileutils'
require 'shellwords'
require 'English'

module Transpec
  class DynamicAnalyzer
    EVAL_TARGET_TYPES = [:object, :context]
    ANALYSIS_METHOD = 'transpec_analysis'
    HELPER_FILE = 'transpec_analysis_helper.rb'
    RESULT_FILE = 'transpec_analysis_result.json'
    HELPER_SOURCE = <<-END
      require 'pathname'
      require 'json'

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
      if @project.require_bundler?
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
        FileUtils.cp_r(@project.path, tmpdir)
        @copied_project_path = File.join(tmpdir, @project.basename)
        Dir.chdir(@copied_project_path) do
          yield
        end
      end
    ensure
      @in_copied_project = false
    end

    def run_rspec(paths)
      @project.with_bundler_clean_env do
        ENV['SPEC_OPTS'] = ['-r', "./#{HELPER_FILE}"].shelljoin

        command = "#{rspec_command} #{paths.shelljoin}"

        if silent?
          rspec_output = `#{command} 2> /dev/null`
        else
          system(command)
        end

        unless $CHILD_STATUS.exitstatus == 0
          message = 'Dynamic analysis failed!'
          if silent?
            message << "\n"
            message << rspec_output
          end
          fail message
        end
      end
    end
  end
end
