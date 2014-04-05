# coding: utf-8

require 'transpec/commit_message'
require 'transpec/configuration'
require 'transpec/converter'
require 'transpec/dynamic_analyzer'
require 'transpec/file_finder'
require 'transpec/option_parser'
require 'transpec/project'
require 'transpec/report'
require 'rainbow'
require 'rainbow/ext/string' unless String.method_defined?(:color)

module Transpec
  class CLI
    attr_reader :project, :configuration, :report

    def self.run(args = ARGV)
      new.run(args)
    end

    def initialize
      @project = Project.new
      @configuration = Configuration.new
      @report = Report.new
    end

    def run(args)
      begin
        paths = OptionParser.new(configuration).parse(args)
        fail_if_should_not_continue!
      rescue => error
        warn error.message
        return false
      end

      begin
        process(paths)
      rescue DynamicAnalyzer::AnalysisError
        warn_dynamic_analysis_error
        return false
      end

      display_summary
      generate_commit_message
      display_final_guide

      true
    end

    def process(paths)
      runtime_data = nil

      unless configuration.skip_dynamic_analysis?
        runtime_data = run_dynamic_analysis(paths)
      end

      FileFinder.find(paths).each do |file_path|
        convert_file(file_path, runtime_data)
      end
    end

    def convert_file(file_path, runtime_data = nil)
      puts "Converting #{file_path}"

      converter = Converter.new(configuration, project.rspec_version, runtime_data)
      converter.convert_file!(file_path)

      warn_annotations(converter.report)
      report << converter.report
    rescue Parser::SyntaxError => error
      report.syntax_errors << error
      warn_syntax_error(error)
    end

    private

    def fail_if_should_not_continue!
      unless configuration.forced?
        if Git.command_available? && Git.inside_of_repository? && !Git.clean?
          fail 'The current Git repository is not clean. Aborting.'
        end
      end

      if project.rspec_version < Transpec.required_rspec_version
        fail "Your project must have rspec gem dependency #{Transpec.required_rspec_version} " \
             "or later but currently it's #{project.rspec_version}. Aborting."
      end
    end

    def run_dynamic_analysis(paths)
      runtime_data = nil

      puts 'Copying the project for dynamic analysis...'

      DynamicAnalyzer.new(rspec_command: configuration.rspec_command) do |analyzer|
        puts "Running dynamic analysis with command #{analyzer.rspec_command.inspect}..."
        runtime_data = analyzer.analyze(paths)
      end

      puts

      runtime_data
    end

    def display_summary
      puts

      unless report.records.empty?
        puts 'Summary:'
        puts
        puts report.colored_summary
        puts
      end

      puts report.colored_stats
    end

    def generate_commit_message
      return if report.records.empty?
      return unless Git.command_available? && Git.inside_of_repository?

      commit_message = CommitMessage.new(report, project.rspec_version, ARGV)
      Git.write_commit_message(commit_message.to_s)

      puts
      puts 'A commit message that describes the conversion summary was generated to'.color(:cyan)
      puts '.git/COMMIT_EDITMSG. To use the message, type the following command for'.color(:cyan)
      puts 'the next commit:'.color(:cyan)
      puts '    git commit -eF .git/COMMIT_EDITMSG'
    end

    def display_final_guide
      return if report.records.empty?

      puts
      puts "Done! Now run #{'rspec'.bright} and check if everything is green."
    end

    def warn_dynamic_analysis_error
      warn 'Failed running dynamic analysis. ' \
           'Transpec runs your specs in a copied project directory. ' \
           'If your project requires some special setup or commands to run specs, ' \
           'use -c/--rspec-command option.'
    end

    def warn_syntax_error(error)
      warn "Syntax error at #{error.diagnostic.location}. Skipping the file.".color(:red)
    end

    def warn_annotations(report)
      annotations = report.records.map(&:annotation).compact
      annotations.concat(report.conversion_errors)
      annotations.sort_by! { |a| a.source_range.line }

      annotations.each do |annotation|
        warn_annotation(annotation)
      end
    end

    def warn_annotation(annotation)
      color = annotation.is_a?(Annotation) ? :yellow : :magenta
      message = annotation.message.color(color) + $RS
      message << highlighted_source(annotation)
      warn message
    end

    def highlighted_source(annotation)
      filename = annotation.source_buffer.name.color(:cyan)

      line_number = annotation.source_range.line

      source = annotation.source_range.source_line
      highlight_range = annotation.source_range.column_range
      source[highlight_range] = source[highlight_range].underline

      [filename, line_number, source].join(':')
    end
  end
end
