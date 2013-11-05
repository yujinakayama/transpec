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
        paths = OptionParser.new(@configuration).parse(args)
        fail_if_should_not_continue!
      rescue => error
        warn error.message
        return false
      end

      process(paths)

      display_summary
      generate_commit_message if @configuration.generate_commit_message?
      display_final_guide

      true
    end

    def process(paths)
      runtime_data = nil

      unless @configuration.skip_dynamic_analysis?
        puts 'Copying project for dynamic analysis...'
        DynamicAnalyzer.new(rspec_command: @configuration.rspec_command) do |analyzer|
          puts "Running dynamic analysis with command \"#{analyzer.rspec_command}\"..."
          runtime_data = analyzer.analyze(paths)
        end
        puts
      end

      FileFinder.find(paths).each do |file_path|
        convert_file(file_path, runtime_data)
      end
    end

    def convert_file(file_path, runtime_data = nil)
      puts "Converting #{file_path}"

      converter = Converter.new(@configuration, @project.rspec_version, runtime_data, @report)
      converter.convert_file!(file_path)

      @report.invalid_context_errors.concat(converter.invalid_context_errors)

      converter.invalid_context_errors.each do |error|
        warn_invalid_context_error(error)
      end
    rescue Parser::SyntaxError => error
      @report.syntax_errors << error
      warn_syntax_error(error)
    end

    private

    def fail_if_should_not_continue!
      unless @configuration.forced?
        if Git.command_available? && Git.inside_of_repository? && !Git.clean?
          fail 'The current Git repository is not clean. Aborting.'
        end
      end

      if @project.rspec_version < Transpec.required_rspec_version
        fail "Your project must have rspec gem dependency #{Transpec.required_rspec_version} " +
             "or later but currently it's #{@project.rspec_version}. Aborting."
      end
    end

    def display_summary
      puts

      unless @report.records.empty?
        puts 'Summary:'
        puts
        puts @report.colored_summary
        puts
      end

      puts @report.colored_stats
    end

    def generate_commit_message
      return if @report.records.empty?

      commit_message = CommitMessage.new(@report, ARGV)
      Git.write_commit_message(commit_message.to_s)

      puts
      puts 'Commit message was generated to .git/COMMIT_EDITMSG.'.color(:cyan)
      puts 'Use the following command for the next commit:'.color(:cyan)
      puts '    git commit -eF .git/COMMIT_EDITMSG'
    end

    def display_final_guide
      puts
      puts "Done! Now run #{'rspec'.bright} and check if all the converted specs pass."
    end

    def warn_syntax_error(error)
      warn "Syntax error at #{error.diagnostic.location}. Skipping the file.".color(:red)
    end

    def warn_invalid_context_error(error)
      message = error.message.color(:yellow) + $RS
      message << highlighted_source(error)
      warn message
    end

    def highlighted_source(error)
      filename = error.source_buffer.name.color(:cyan)

      line_number = error.source_range.line

      source = error.source_range.source_line
      highlight_range = error.source_range.column_range
      source[highlight_range] = source[highlight_range].underline

      [filename, line_number, source].join(':')
    end
  end
end
