# coding: utf-8

require 'spec_helper'
require 'transpec/record'

module Transpec
  describe Record do
    subject(:record) { Record.new(old_syntax, new_syntax, options) }
    let(:old_syntax) { 'obj.should' }
    let(:new_syntax) { 'expect(obj).to' }
    let(:options) { {} }

    describe '.new' do
      context 'when invalid type is passed' do
        it 'raises error' do
          lambda do
            Record.new('foo', 'bar', type: :unknown_type)
          end.should raise_error(/invalid type/i)
        end
      end
    end

    describe '#type' do
      subject { record.type }

      context 'when it has both old and new syntaxes' do
        let(:old_syntax) { 'obj.should' }
        let(:new_syntax) { 'expect(obj).to' }
        it { should == :conversion }
      end

      context 'when it has only new syntax' do
        let(:old_syntax) { nil }
        let(:new_syntax) { 'expect(obj).to' }
        it { should == :addition }
      end

      context 'when it has only old syntax' do
        let(:old_syntax) { 'obj.should' }
        let(:new_syntax) { nil }
        it { should == :removal }
      end

      context 'when the type is specified explicitly' do
        let(:old_syntax) { 'foo = true' }
        let(:new_syntax) { 'foo = false' }
        let(:options) { { type: :modification } }
        it { should == :modification }
      end
    end

    describe '#to_s' do
      subject { record.to_s }

      context "when it's a conversion" do
        let(:old_syntax) { 'obj.should' }
        let(:new_syntax) { 'expect(obj).to' }

        it 'returns "Conversion from `old syntax` to `new syntax`"' do
          record.to_s.should == 'Conversion from `obj.should` to `expect(obj).to`'
        end
      end

      context "when it's an addition" do
        let(:old_syntax) { nil }
        let(:new_syntax) { 'expect(obj).to' }

        it 'returns "Addition of `new syntax`"' do
          record.to_s.should == 'Addition of `expect(obj).to`'
        end
      end

      context "when it's a removal" do
        let(:old_syntax) { 'obj.should' }
        let(:new_syntax) { nil }

        it 'returns "Removal of `old syntax`"' do
          record.to_s.should == 'Removal of `obj.should`'
        end
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

        def type
          :modification
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
              type: :modification,
        annotation: 'some annotation'
      }.each do |attribute, value|
        it "sets builder's ##{attribute} value to record's ##{attribute}" do
          record.send(attribute).should == value
        end
      end
    end
  end
end
