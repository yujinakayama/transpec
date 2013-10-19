# coding: utf-8

require 'transpec/file_finder'
require 'transpec/dynamic_analyzer/runtime_data'
require 'transpec/dynamic_analyzer/rewriter'
require 'tmpdir'
require 'fileutils'
require 'shellwords'
require 'English'

module Transpec
  class DynamicAnalyzer
    ANALYSIS_METHOD = 'transpec_analysis'
    HELPER_FILE = 'transpec_analysis_helper.rb'
    RESULT_FILE = 'transpec_analysis_result.dump'
    HELPER_SOURCE = <<-END
      require 'pathname'

      module TranspecAnalysis
        def self.data
          @data ||= {}
        end

        def self.node_id(filename, line, column)
          absolute_path = File.expand_path(filename)
          relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.pwd).to_s
          [relative_path, line, column].join('_')
        end

        at_exit do
          File.open('#{RESULT_FILE}', 'w') do |file|
            Marshal.dump(data, file)
          end
        end
      end

      def #{ANALYSIS_METHOD}(object, analysis_codes, context, filename, line, column)
        pair_array = analysis_codes.map do |key, code|
          [key, object.instance_eval(code)]
        end

        object_data = Hash[pair_array]

        object_data[:context_class_name] = context.class.name

        id = TranspecAnalysis.node_id(filename, line, column)
        TranspecAnalysis.data[id] = object_data

        object
      end
    END

    attr_reader :project_path, :silent
    alias_method :silent?, :silent

    def initialize(project_path = nil, rspec_command = nil, silent = false)
      @project_path = project_path || Dir.pwd
      @rspec_command = rspec_command
      @silent = silent
    end

    def rspec_command
      @rspec_command ||= if File.exist?('Gemfile')
                           'bundle exec rspec'
                         else
                           'rspec'
                         end
    end

    def analyze
      hash = nil

      in_copied_project do
        rewriter = Rewriter.new

        FileFinder.find(['spec']).each do |file_path|
          rewriter.rewrite_file!(file_path)
        end

        File.write(HELPER_FILE, HELPER_SOURCE)

        run_rspec

        File.open(RESULT_FILE) do |file|
          hash = Marshal.load(file)
        end
      end

      RuntimeData.new(hash)
    end

    def in_copied_project
      Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r(@project_path, tmpdir)
        copied_project_path = File.join(tmpdir, File.basename(@project_path))
        Dir.chdir(copied_project_path) do
          yield
        end
      end
    end

    def run_rspec
      with_bundler_clean_env do
        ENV['SPEC_OPTS'] = ['-r', "./#{HELPER_FILE}"].shelljoin

        if silent?
          rspec_output = `#{rspec_command}`
        else
          system(rspec_command)
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
