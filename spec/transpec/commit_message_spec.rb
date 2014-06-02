# coding: utf-8

require 'spec_helper'
require 'transpec/commit_message'
require 'transpec/report'
require 'transpec/record'
require 'transpec/rspec_version'

module Transpec
  describe CommitMessage do
    subject(:commit_message) { CommitMessage.new(report, rspec_version, cli_args) }
    let(:report) { Report.new }
    let(:rspec_version) { RSpecVersion.new('2.99.0.beta1') }
    let(:cli_args) { ['--force', '--rspec-command', 'bundle exec rspec'] }

    before do
      report.records << Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)')
      report.records << Record.new('obj.should', 'expect(obj).to')
      report.records << Record.new('obj.should', 'expect(obj).to')
    end

    describe '#to_s' do
      it 'wraps lines within 72 characters except URLs' do
        commit_message.to_s.each_line do |line|
          next if line.match(%r{\bhttps?://})
          line.chomp.size.should <= 72
        end
      end

      let(:lines) { commit_message.to_s.lines.to_a }

      describe 'first line' do
        it 'has concise summary' do
          lines[0].chomp.should == 'Convert specs to RSpec 2.99.0.beta1 syntax with Transpec'
        end
      end

      describe 'second line' do
        it 'has blank line' do
          lines[1].chomp.should be_empty
        end
      end

      let(:body_lines) { lines[2..-1] }

      describe 'body' do
        it 'has Transpec description at the beginning'  do
          body_lines[0].chomp
            .should match(/^This conversion is done by Transpec \d+\.\d+\.\d+ with the following command:$/)
          body_lines[1].chomp
            .should ==     '    transpec --force --rspec-command "bundle exec rspec"'
        end

        it 'has blank line after the preface' do
          body_lines[2].chomp.should be_empty
        end

        it 'has conversion summary' do
          body_lines[3..-3].join('').should == <<-END.gsub(/^\s+\|/, '')
            |* 2 conversions
            |    from: obj.should
            |      to: expect(obj).to
            |
            |* 1 conversion
            |    from: obj.stub(:message)
            |      to: allow(obj).to receive(:message)
          END
        end

        it 'has blank line after the summary' do
          body_lines[-2].chomp.should be_empty
        end

        it 'has the URL at the last line' do
          body_lines[-1].chomp.should ==
            'For more details: https://github.com/yujinakayama/transpec#supported-conversions'
        end
      end
    end
  end
end
