# coding: utf-8

require 'transpec/configuration'
require 'transpec/git'
require 'transpec/version'
require 'optparse'
require 'rainbow'

module Transpec
  class OptionParser
    CONFIG_ATTRS_FOR_CLI_TYPES = {
      expect_to_matcher: :convert_to_expect_to_matcher=,
      expect_to_receive: :convert_to_expect_to_receive=,
       allow_to_receive: :convert_to_allow_to_receive=,
             have_items: :convert_have_items=,
             deprecated: :replace_deprecated_method=
    }

    attr_reader :configuration

    def initialize(configuration = Configuration.new)
      @configuration = configuration
    end

    def parse(args)
      args = args.dup
      parser.parse!(args)
      args
    end

    # rubocop:disable MethodLength
    def parser
      parser = ::OptionParser.new
      parser.banner = "Usage: transpec [options] [files or directories]\n\n"

      parser.on(
        '-f', '--force',
        'Force processing even if the current Git',
        'repository is not clean.'
      ) do
        @configuration.forced = true
      end

      parser.on(
        '-m', '--generate-commit-message',
        'Generate commit message that describes',
        'conversion summary. Only Git is supported.'
      ) do
        unless Git.inside_of_repository?
          fail '-m/--generate-commit-message option is specified but not in a Git repository'
        end

        @configuration.generate_commit_message = true
      end

      parser.on(
        '-d', '--disable TYPE[,TYPE...]',
        'Disable specific conversions.',
        'Available conversion types:',
        "  #{'expect_to_matcher'.bright} (from #{'should'.underline})",
        "  #{'expect_to_receive'.bright} (from #{'should_receive'.underline})",
        "  #{'allow_to_receive'.bright}  (from #{'stub'.underline})",
        "  #{'have_items'.bright} (to #{'expect(obj.size).to eq(x)'.underline})",
        "  #{'deprecated'.bright} (e.g. from #{'mock'.underline} to #{'double'.underline})",
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
        "Specify negative form of #{'to'.underline} that is used",
        "in #{'expect(...).to'.underline} syntax.",
        "Either #{'not_to'.bright} or #{'to_not'.bright}.",
        "Default: #{'not_to'.bright}"
      ) do |form|
        @configuration.negative_form_of_to = form
      end

      parser.on(
        '-p', '--no-parentheses-matcher-arg',
        'Suppress parenthesizing argument of matcher',
        'when converting operator to non-operator',
        "in #{'expect'.underline} syntax. Note that it will be",
        'parenthesized even if this option is',
        'specified when parentheses are necessary to',
        'keep the meaning of the expression.',
        'By default, arguments of the following',
        'operator matchers will be parenthesized.',
        "  #{'== 10'.underline} to #{'eq(10)'.underline}",
        "  #{'=~ /pattern/'.underline} to #{'match(/pattern/)'.underline}",
        "  #{'=~ [1, 2]'.underline} to #{'match_array([1, 2])'.underline}"
      ) do
        @configuration.parenthesize_matcher_arg = false
      end

      parser.on(
        '-c', '--rspec-command COMMAND',
        'Specify command to run RSpec that is used',
        'for dynamic analysis.',
        'Default: "bundle exec rspec"'
      ) do |command|
        @configuration.rspec_command = command
      end

      parser.on('--no-color', 'Disable color in the output.') do
        Sickill::Rainbow.enabled = false
      end

      parser.on('--version', 'Show Transpec version.') do
        puts Version.to_s
        exit
      end

      parser
    end
    # rubocop:enable MethodLength
  end
end
