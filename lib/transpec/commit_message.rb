# coding: utf-8

require 'transpec/version'

module Transpec
  class CommitMessage
    def initialize(report, cli_args = [])
      @report = report
      @cli_args = cli_args
    end

    def to_s
      conversion_summary = @report.summary(bullet: '*', separate_by_blank_line: true)

      <<-END.gsub(/^\s+\|/, '').chomp
        |Convert specs to latest RSpec syntax with Transpec
        |
        |This conversion is done by Transpec #{Transpec::Version} with the following command:
        |    transpec #{@cli_args.join(' ')}
        |
        |#{conversion_summary}
      END
    end
  end
end
