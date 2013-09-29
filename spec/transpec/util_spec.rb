# coding: utf-8

require 'spec_helper'
require 'transpec/util'

module Transpec
  describe Util do
    include_context 'parsed objects'
    include ::AST::Sexp

    describe '#const_name' do
      subject { Util.const_name(const_node) }

      let(:const_node) do
        AST::Scanner.scan(ast) do |node|
          return node if node.type == :const
        end
        fail 'No const node is found!'
      end

      context 'when the passed node is not :const type' do
        let(:const_node) do
          s(:lvasgn, :foo,
            s(:int, 1))
        end

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
  end
end
