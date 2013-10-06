# coding: utf-8

require 'spec_helper'
require 'transpec/commit_message'
require 'transpec/report'
require 'transpec/record'

module Transpec
  describe CommitMessage do
    subject(:commit_message) { CommitMessage.new(report, cli_args) }
    let(:report) { Report.new }
    let(:cli_args) { %w(--force --commit-message) }

    before do
      report.records << Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)')
      report.records << Record.new('obj.should', 'expect(obj).to')
      report.records << Record.new('obj.should', 'expect(obj).to')
    end

    describe '#to_s' do
      it 'wraps lines within 72 characters' do
        commit_message.to_s.each_line do |line|
          line.chomp.size.should <= 72
        end
      end

      let(:lines) { commit_message.to_s.lines }

      it 'has concise summary at first line' do
        lines[0].chomp.should == 'Convert specs to latest RSpec syntax with Transpec'
      end

      it 'has blank line at second line' do
        lines[1].chomp.should be_empty
      end

      let(:body_lines) { commit_message.to_s.lines[2..-1] }

      it 'has Transpec description at the beginning of the body'  do
        body_lines[0].chomp
          .should match(/^This conversion is done by Transpec \d+\.\d+\.\d+ with the following command:$/)
        body_lines[1].chomp
          .should ==     '    transpec --force --commit-message'
      end

      it 'has blank line after the preface in the body' do
        body_lines[2].chomp.should be_empty
      end

      it 'has conversion summary in the body' do
        body_lines[3..-1].join('').should == <<-END.gsub(/^\s+\|/, '')
          |* 2 conversions
          |    from: obj.should
          |      to: expect(obj).to
          |
          |* 1 conversion
          |    from: obj.stub(:message)
          |      to: allow(obj).to receive(:message)
        END
      end
    end
  end
end
