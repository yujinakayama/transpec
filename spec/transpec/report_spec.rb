# coding: utf-8

require 'spec_helper'
require 'transpec/report'
require 'transpec/record'
require 'transpec/syntax'

module Transpec
  describe Report do
    subject(:report) { Report.new }

    before do
      report.records << Record.new('obj.stub(:message)', 'allow(obj).to receive(:message)')
      report.records << Record.new('obj.should', 'expect(obj).to')
      report.records << Record.new('obj.should', 'expect(obj).to')
      report.invalid_context_errors <<
        Syntax::InvalidContextError.new(double('range'), '#should', '#expect')
    end

    describe '#unique_record_counts' do
      subject(:unique_record_counts) { report.unique_record_counts }

      it 'returns counts for unique records' do
        unique_record_counts.size.should == 2
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
        unique_record_counts.values.should == [2, 1]
      end
    end

    describe '#summary' do
      subject(:summary) { report.summary }

      it 'returns summary string' do
        summary.should == <<-END.gsub(/^\s+\|/, '')
          |2 conversions
          |  from: obj.should
          |    to: expect(obj).to
          |1 conversion
          |  from: obj.stub(:message)
          |    to: allow(obj).to receive(:message)
          |
          |3 conversions, 1 incomplete, 0 errors
        END
      end
    end
  end
end
