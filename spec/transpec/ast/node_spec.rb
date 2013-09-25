# coding: utf-8

require 'spec_helper'
require 'transpec/ast/node'

module Transpec
  module AST
    describe Node do
      include ::AST::Sexp
      include_context 'parsed objects'

      let(:source) do
        <<-END
          def some_method(arg_a, arg_b)
            do_something(arg_a)
          end
        END
      end

      # (def :some_method
      #   (args
      #     (arg :arg_a)
      #     (arg :arg_b))
      #   (send nil :do_something
      #     (lvar :arg_a)))

      describe '#each_child_node' do
        let(:expected_types) { [:args, :send] }

        context 'when a block is given' do
          it 'yields each child node' do
            index = 0

            ast.each_child_node do |node|
              expected_type = expected_types[index]
              node.type.should == expected_type
              index += 1
            end

            index.should_not == 0
          end

          it 'returns itself' do
            returned_value = ast.each_child_node { }
            returned_value.should be(ast)
          end
        end

        context 'when no block is given' do
          it 'returns enumerator' do
            ast.each_child_node.should be_a(Enumerator)
          end

          describe 'the returned enumerator' do
            it 'enumerates the child nodes' do
              enumerator = ast.each_child_node

              expected_types.each do |expected_type|
                enumerator.next.type.should == expected_type
              end
            end
          end
        end
      end

      describe '#each_descendent_node' do
        let(:expected_types) { [:args, :arg, :arg, :send, :lvar] }

        context 'when a block is given' do
          it 'yields each descendent node with depth first order' do
            index = 0

            ast.each_descendent_node do |node|
              expected_type = expected_types[index]
              node.type.should == expected_type
              index += 1
            end

            index.should_not == 0
          end

          it 'returns itself' do
            returned_value = ast.each_descendent_node { }
            returned_value.should be(ast)
          end
        end

        context 'when no block is given' do
          it 'returns enumerator' do
            ast.each_descendent_node.should be_a(Enumerator)
          end

          describe 'the returned enumerator' do
            it 'enumerates the child nodes' do
              enumerator = ast.each_descendent_node

              expected_types.each do |expected_type|
                enumerator.next.type.should == expected_type
              end
            end
          end
        end
      end
    end
  end
end
