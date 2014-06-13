# coding: utf-8

require 'spec_helper'
require 'transpec/record'

module Transpec
  describe Record do
    subject(:report) { Record.new(old_syntax, new_syntax) }
    let(:old_syntax) { 'obj.should' }
    let(:new_syntax) { 'expect(obj).to' }

    [
      :old_syntax,
      :old_syntax_type,
      :new_syntax,
      :new_syntax_type
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
