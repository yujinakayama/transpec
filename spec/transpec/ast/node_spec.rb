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
            1.times do
              do_something(arg_a)
            end
          end
        END
      end

      # (def :some_method
      #   (args
      #     (arg :arg_a)
      #     (arg :arg_b))
      #   (block
      #     (send
      #       (int 1) :times)
      #     (args)
      #     (send nil :do_something
      #       (lvar :arg_a))))

      describe '#parent_node' do
        context 'when the node has parent' do
          let(:target_node) do
            ast.each_descendent_node do |node|
              return node if node == s(:args)
            end
          end

          it 'returns the parent node' do
            target_node.parent_node.type.should == :block
          end
        end

        context 'when the node has parent' do
          it 'returns nil' do
            ast.parent_node.should be_nil
          end
        end
      end

      describe '#each_ancestor_node' do
        let(:target_node) do
          ast.each_descendent_node do |node|
            return node if node == s(:args)
          end
        end

        let(:expected_types) { [:block, :def] }

        context 'when a block is given' do
          it 'yields each ancestor node' do
            index = 0

            target_node.each_ancestor_node do |node|
              expected_type = expected_types[index]
              node.type.should == expected_type
              index += 1
            end

            index.should_not == 0
          end

          it 'returns itself' do
            returned_value = target_node.each_ancestor_node { }
            returned_value.should be(target_node)
          end
        end

        context 'when no block is given' do
          it 'returns enumerator' do
            target_node.each_ancestor_node.should be_a(Enumerator)
          end

          describe 'the returned enumerator' do
            it 'enumerates the ancestor nodes' do
              enumerator = target_node.each_ancestor_node

              expected_types.each do |expected_type|
                enumerator.next.type.should == expected_type
              end
            end
          end
        end
      end

      describe '#each_child_node' do
        let(:expected_types) { [:args, :block] }

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
        let(:expected_types) do
          [:args, :arg, :arg, :block, :send, :int, :args, :send, :lvar]
        end

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
