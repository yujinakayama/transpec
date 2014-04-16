# coding: utf-8

require 'spec_helper'
require 'transpec/record'

module Transpec
  describe Record do
    subject(:report) { Record.new(original_syntax, converted_syntax) }
    let(:original_syntax) { 'obj.should' }
    let(:converted_syntax) { 'expect(obj).to' }

    [
      :original_syntax,
      :original_syntax_type,
      :converted_syntax,
      :converted_syntax_type
    ].each do |method|
      it "forbids override of ##{method}" do
        lambda do
          Class.new(Record) do
            define_method(method) {}
          end
        end.should raise_error(/override/)
      end
    end

    describe '#to_s' do
      it 'returns "`original syntax` -> `converted syntax`"' do
        report.to_s.should == '`obj.should` -> `expect(obj).to`'
      end
    end
  end
end
