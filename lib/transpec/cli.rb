# coding: utf-8

require 'transpec/configuration'
require 'transpec/git'
require 'transpec/rewriter'
require 'transpec/version'
require 'optparse'
require 'find'

module Transpec
  class CLI
    CONFIG_ATTRS_FOR_CLI_TYPES = {
      expect_to_matcher: :convert_to_expect_to_matcher=,
      expect_to_receive: :convert_to_expect_to_receive=,
       allow_to_receive: :convert_to_allow_to_receive=,
             deprecated: :replace_deprecated_method=
    }

    attr_reader :configuration, :forced
    alias_method :forced?, :forced

    def self.run(args = ARGV)
      new.run(args)
    end

    def initialize
      @configuration = Configuration.new
      @forced = false
    end

    def run(args)
      non_option_args = parse_options(args)

      fail_if_should_not_continue!

      paths = non_option_args

      if paths.empty?
        if Dir.exists?('spec')
          paths = ['spec']
        else
          fail ArgumentError, 'Specify target files or directories.'
        end
      end

      target_files(paths).each do |file_path|
        puts "Processing #{file_path}"
        rewriter = Rewriter.new(@configuration)
        rewriter.rewrite_file!(file_path)
      end

      # TODO: Print summary

      true
    rescue => error
      warn error.message
      false
    end

    # rubocop:disable MethodLength
    def parse_options(args)
      parser = OptionParser.new
      parser.banner = "Usage: transpec [options] [files or directories]\n\n"

      parser.on(
        '-f', '--force',
        'Force processing even if the current Git',
        'repository is not clean.'
      ) do
        @forced = true
      end

      parser.on(
        '-d', '--disable TYPE[,TYPE...]',
        'Disable specific conversions.',
        'Available conversion types:',
        '  expect_to_matcher (from `should`)',
        '  expect_to_receive (from `should_receive`)',
        '  allow_to_receive  (from `stub`)',
        '  deprecated (e.g. from `stub!` to `stub`)',
        'These are all enabled by default.'
      ) do |types|
        types.split(',').each do |type|
          config_attr = CONFIG_ATTRS_FOR_CLI_TYPES[type.to_sym]
          fail ArgumentError, "Unknown conversion type #{type.inspect}" unless config_attr
          @configuration.send(config_attr, false)
        end
      end

      parser.on(
        '-n', '--negative-form FORM',
        'Specify negative form of `to` that is used',
        'in `expect(...).to` syntax.',
        'Either `not_to` or `to_not`.',
        'Default: not_to'
      ) do |form|
        @configuration.negative_form_of_to = form
      end

      parser.on(
        '-p', '--no-parentheses-matcher-arg',
        'Suppress parenthesizing argument of matcher',
        'when converting operator to non-operator',
        'in `expect` syntax. Note that it will be',
        'parenthesized even if this option is',
        'specified when parentheses are necessary to',
        'keep the meaning of the expression.',
        'By default, arguments of the following',
        'operator matchers will be parenthesized.',
        '  `== 10` to `eq(10)`',
        '  `=~ /pattern/` to `match(/pattern/)`',
        '  `=~ [1, 2]` to `match_array([1, 2])`'
      ) do
        @configuration.parenthesize_matcher_arg = false
      end

      parser.on('--version', 'Show Transpec version.') do
        puts Version.to_s
        exit
      end

      args = args.dup
      parser.parse!(args)
      args
    end
    # rubocop:enable MethodLength

    def target_files(paths)
      paths.reduce([]) do |file_paths, path|
        if File.directory?(path)
          file_paths.concat(ruby_files_in_directory(path))
        elsif File.file?(path)
          file_paths << path
        elsif !File.exists?(path)
          fail ArgumentError, "No such file or directory #{path.inspect}"
        end
      end
    end

    private

    def ruby_files_in_directory(directory_path)
      ruby_file_paths = []

      Find.find(directory_path) do |path|
        next unless File.file?(path)
        next unless File.extname(path) == '.rb'
        ruby_file_paths << path
      end

      ruby_file_paths
    end

    def fail_if_should_not_continue!
      return if forced?

      # TODO: Check each repository of target files / directories,
      #   not only the current working directory.
      return unless Git.command_available?
      return unless Git.inside_of_repository?
      return if Git.clean?

      fail 'The current Git repository is not clean. Aborting.'
    end
  end
end
