# coding: utf-8

require 'spec_helper'
require 'transpec/record'

module Transpec
  describe Record do
    subject(:report) { Record.new(old_syntax, new_syntax) }
    let(:old_syntax) { 'obj.should' }
    let(:new_syntax) { 'expect(obj).to' }

    describe '#to_s' do
      it 'returns "`original syntax` -> `converted syntax`"' do
        report.to_s.should == '`obj.should` -> `expect(obj).to`'
      end
    end
  end

  describe RecordBuilder do
    describe '.build' do
      builder_class = Class.new(RecordBuilder) do
        attr_reader :some_attr

        def initialize(some_attr)
          @some_attr = some_attr
        end

        def old_syntax
          "obj.should be #{some_attr}"
        end

        def new_syntax
          "expect(obj).to be #{some_attr}"
        end

        def annotation
          'some annotation'
        end
      end

      let(:record) { builder_class.build('something') }

      it 'returns an instance of Record' do
        record.should be_a(Record)
      end

      {
        old_syntax: 'obj.should be something',
        new_syntax: 'expect(obj).to be something',
        annotation: 'some annotation'
      }.each do |attribute, value|
        it "sets builder's ##{attribute} value to record's ##{attribute}" do
          record.send(attribute).should == value
        end
      end
    end
  end
end
