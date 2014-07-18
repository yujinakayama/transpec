# coding: utf-8

require 'spec_helper'
require 'transpec/report'
require 'transpec/record'
require 'transpec/syntax'

module Transpec
  describe Report do
    subject(:report) { Report.new }

    before do
      options = { annotation: double('annotation') }
      report.records << Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)', options)
      report.records << Record.new('obj.should', 'expect(obj).to')
      report.records << Record.new('obj.should', 'expect(obj).to', options)
      report.records << Record.new(nil, 'RSpec.configure { |c| c.infer_spec_type_from_file_location! }')
      report.conversion_errors << ContextError.new('#should', '#expect', double('range'))
    end

    describe '#unique_record_counts' do
      subject(:unique_record_counts) { report.unique_record_counts }

      it 'returns counts for unique records' do
        unique_record_counts.size.should == 3
      end

      it 'returns hash with record as key and count as value' do
        unique_record_counts.each do |record, count|
          case record
          when Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)')
            count.should == 1
          when Record.new('obj.should', 'expect(obj).to')
            count.should == 2
          end
        end
      end

      it 'is sorted by count in descending order' do
        unique_record_counts.values.should == [2, 1, 1]
      end
    end

    describe '#summary' do
      it 'returns summary string' do
        report.summary.should == <<-END.gsub(/^\s+\|/, '')
          |2 conversions
          |  from: obj.should
          |    to: expect(obj).to
          |1 conversion
          |  from: obj.stub(:message)
          |    to: allow(obj).to receive(:message)
          |1 addition
          |    of: RSpec.configure { |c| c.infer_spec_type_from_file_location! }
        END
      end

      context 'when :separate_by_blank_line option is enabled' do
        it 'separates conversion entries by blank line' do
          report.summary(separate_by_blank_line: true).should == <<-END.gsub(/^\s+\|/, '')
            |2 conversions
            |  from: obj.should
            |    to: expect(obj).to
            |
            |1 conversion
            |  from: obj.stub(:message)
            |    to: allow(obj).to receive(:message)
            |
            |1 addition
            |    of: RSpec.configure { |c| c.infer_spec_type_from_file_location! }
          END
        end
      end

      context 'when :bullet option is specified' do
        it 'adds the bullet for each conversion entry' do
          report.summary(bullet: '-').should == <<-END.gsub(/^\s+\|/, '')
            |- 2 conversions
            |    from: obj.should
            |      to: expect(obj).to
            |- 1 conversion
            |    from: obj.stub(:message)
            |      to: allow(obj).to receive(:message)
            |- 1 addition
            |      of: RSpec.configure { |c| c.infer_spec_type_from_file_location! }
          END
        end
      end
    end

    describe '#stats' do
      it 'returns stats string' do
        report.stats.should == '4 conversions, 1 incomplete, 2 warnings, 0 errors'
      end
    end

    describe '#<<' do
      subject(:concated_report) { report << another_report }

      let(:another_report) do
        report = Report.new
        report.records << Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)')
        report.conversion_errors << ContextError.new('#should', '#expect', double('range'))
        report.conversion_errors << ContextError.new('#stub', '#allow', double('range'))
        report.file_errors << double('file error')
        report
      end

      it 'returns the receiver' do
        concated_report.should equal(report)
      end

      it 'concats records' do
        concated_report.should have(5).records
      end

      it 'concats conversion errors' do
        concated_report.should have(3).conversion_errors
      end

      it 'concats file errors' do
        concated_report.should have(1).file_errors
      end
    end
  end
end
