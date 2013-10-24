# coding: utf-8

require 'transpec/file_finder'
require 'transpec/dynamic_analyzer/runtime_data'
require 'transpec/dynamic_analyzer/rewriter'
require 'tmpdir'
require 'fileutils'
require 'ostruct'
require 'shellwords'
require 'English'

module Transpec
  class DynamicAnalyzer
    EVAL_TARGET_TYPES = [:object, :context]
    ANALYSIS_METHOD = 'transpec_analysis'
    HELPER_FILE = 'transpec_analysis_helper.rb'
    RESULT_FILE = 'transpec_analysis_result.dump'
    HELPER_SOURCE = <<-END
      require 'ostruct'
      require 'pathname'

      module TranspecAnalysis
        @base_pathname = Pathname.pwd

        def self.data
          @data ||= {}
        end

        def self.node_id(filename, begin_pos, end_pos)
          absolute_path = File.expand_path(filename)
          relative_path = Pathname.new(absolute_path).relative_path_from(@base_pathname).to_s
          [relative_path, begin_pos, end_pos].join('_')
        end

        at_exit do
          File.open('#{RESULT_FILE}', 'w') do |file|
            Marshal.dump(data, file)
          end
        end
      end

      def #{ANALYSIS_METHOD}(object, context, analysis_codes, filename, begin_pos, end_pos)
        pair_array = analysis_codes.map do |key, (target_type, code)|
          target = case target_type
                   when :object  then object
                   when :context then context
                   end

          eval_data = OpenStruct.new

          begin
            eval_data.result = target.instance_eval(code)
          rescue Exception => error
            eval_data.error = error
          end

          [key, eval_data]
        end

        object_data = Hash[pair_array]

        id = TranspecAnalysis.node_id(filename, begin_pos, end_pos)
        TranspecAnalysis.data[id] = object_data

        object
      end
    END

    attr_reader :project_path, :rspec_command, :silent
    alias_method :silent?, :silent

    def initialize(options = {})
      @project_path = options[:project_path] || Dir.pwd
      @rspec_command = options[:rspec_command] || default_rspec_command
      @silent = options[:silent] || false

      if block_given?
        in_copied_project do
          yield self
        end
      end
    end

    def default_rspec_command
      if File.exist?('Gemfile')
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
          hash = Marshal.load(file)
          RuntimeData.new(hash)
        end
      end
    end

    def in_copied_project
      return yield if @in_copied_project

      @in_copied_project = true

      Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r(@project_path, tmpdir)
        @copied_project_path = File.join(tmpdir, File.basename(@project_path))
        Dir.chdir(@copied_project_path) do
          yield
        end
      end
    ensure
      @in_copied_project = false
    end

    def run_rspec(paths)
      with_bundler_clean_env do
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

    def with_bundler_clean_env
      if defined?(Bundler)
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
