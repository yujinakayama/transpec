# coding: utf-8

require 'spec_helper'
require 'transpec/util'
require 'ast'

module Transpec
  describe Util do
    include_context 'parsed objects'

    describe '#const_name' do
      subject { Util.const_name(ast) }

      context 'when the passed node is not :const type' do
        let(:source) { 'foo = 1' }

        it 'returns nil' do
          should be_nil
        end
      end

      [
        ['Foo',           'Foo'],
        ['Foo::Bar',      'Foo::Bar'],
        ['Foo::Bar::Baz', 'Foo::Bar::Baz'],
        ['::Foo',         'Foo'],
        ['::Foo::Bar',    'Foo::Bar'],
        ['variable::Foo', 'variable::Foo']
      ].each do |source, expected_return_value|
        context "when the source is #{source.inspect}" do
          let(:source) { source }

          it "returns #{expected_return_value.inspect}" do
            should == expected_return_value
          end
        end
      end
    end

    describe '#here_document?' do
      subject { Util.here_document?(ast) }

      context 'when pseudo-variable __FILE__ node is passed' do
        let(:source) { '__FILE__' }

        it { should be_false }
      end
    end

    describe '#each_forward_chained_node' do
      context 'when a non-send node is passed' do
        let(:source) { ':foo' }

        it 'does not yield' do
          yielded = false

          Util.each_forward_chained_node(ast) do
            yielded = true
          end

          yielded.should be_false
        end
      end
    end

    describe '#expand_range_to_adjacent_whitespaces' do
      let(:node) { ast.each_node.find(&:block_type?) }
      let(:range) { node.loc.begin }
      subject(:expanded_range) { Util.expand_range_to_adjacent_whitespaces(range) }

      context 'when the range is adjacent to whitespaces' do
        let(:source) do
          <<-END
            1.times  { \t do_something }
          END
        end

        it 'returns expanded range that contains adjacent whitespaces' do
          expanded_range.source.should == "  { \t "
        end
      end

      context 'when the range is not adjacent to whitespaces' do
        let(:source) do
          <<-'END'
            1.times{do_something }
          END
        end

        it 'returns un-expanded range' do
          expanded_range.source.should == '{'
        end
      end
    end

    describe '#chainable_source' do
      subject { Util.chainable_source(ast) }

      [
        ['receiver.do_something(arg1, arg2)', 'receiver.do_something(arg1, arg2)'],
        ['receiver.do_something arg1, arg2',  'receiver.do_something(arg1, arg2)'],
        ['receiver[arg1, arg2]',              'receiver[arg1, arg2]'],
        ['receiver + arg',                    '(receiver + arg)']
      ].each do |original, expected|
        context "when the invocation is `#{original}` form" do
          let(:source) { original }

          it "returns `#{expected}`" do
            should == expected
          end
        end
      end
    end
  end
end
