# coding: utf-8

require 'spec_helper'
require 'transpec/ast/scanner'

module Transpec
  module AST
    describe Scanner do
      include_context 'parsed objects'

      let(:source) do
        <<-END
          some_var = 1

          RSpec.configure do |config|
            config.before do
              prepare_something
            end
          end

          module SomeModule
            SOME_CONST = 1

            describe 'something' do
              def some_method(some_arg)
                do_something
              end

              it 'is 1' do
                something.should == 1
              end
            end
          end
        END
      end

      # (begin
      #   (lvasgn :some_var
      #     (int 1))
      #   (block
      #     (send
      #       (const nil :RSpec) :configure)
      #     (args
      #       (arg :config))
      #     (block
      #       (send
      #         (lvar :config) :before)
      #       (args)
      #       (send nil :prepare_something)))
      #   (module
      #     (const nil :SomeModule)
      #     (begin
      #       (casgn nil :SOME_CONST
      #         (int 1))
      #       (block
      #         (send nil :describe
      #           (str "something"))
      #         (args)
      #         (begin
      #           (def :some_method
      #             (args
      #               (arg :some_arg))
      #             (send nil :do_something))
      #           (block
      #             (send nil :it
      #               (str "is 1"))
      #             (args)
      #             (send
      #               (send
      #                 (send nil :something) :should) :==
      #               (int 1))))))))

      describe '.scan' do
        it 'scans nodes with depth first order' do
          expected_node_type_order = [
            :begin,
            :lvasgn,
            :int,
            :block,
            :send,
            :const,
            :args
          ]

          index = 0

          Scanner.scan(ast) do |node|
            expected_node_type = expected_node_type_order[index]
            node.type.should == expected_node_type if expected_node_type
            index += 1
          end

          index.should_not == 0
        end

        it 'passes ancestor nodes of the current node to the block' do
          each_expected_ancestor_nodes_types = [
            [],
            [:begin],
            [:begin, :lvasgn],
            [:begin],
            [:begin, :block],
            [:begin, :block, :send],
            [:begin, :block],
            [:begin, :block, :args]
          ]

          index = 0

          Scanner.scan(ast) do |node, ancestor_nodes|
            expected_ancestor_node_types = each_expected_ancestor_nodes_types[index]
            if expected_ancestor_node_types
              ancestor_node_types = ancestor_nodes.map(&:type)
              ancestor_node_types.should == expected_ancestor_node_types
            end
            index += 1
          end

          index.should_not == 0
        end
      end

      describe '#scope_stack' do
        def brief_of_node(node)
          brief = node.type.to_s
          node.children.each do |child|
            break if child.is_a?(Parser::AST::Node)
            brief << " #{child.inspect}"
          end
          brief
        end

        it 'returns current scope stack' do
          scanner = Scanner.new do |node|
            expected_scope_stack = begin
              case brief_of_node(node)
              when 'lvasgn :some_var'
                []
              when 'send nil :prepare_something'
                [:rspec_configure, :block]
              when 'module'
                []
              when 'const nil :SomeModule'
                # [:module] # TODO
              when 'casgn nil :SOME_CONST'
                [:module]
              when 'send nil :describe'
                # [:module] # TODO
              when 'def :some_method'
                [:module, :example_group]
              when 'arg :some_arg'
                # [:module, :example_group] # TODO
              when 'send nil :do_something'
                [:module, :example_group, :def]
              when 'send nil :it'
                # [:module, :example_group] # TODO
              when 'str "is 1"'
                # [:module, :example_group] # TODO
              when 'send nil :something'
                [:module, :example_group, :block]
              end
            end

            # TODO: Some scope nodes have special child nodes
            #   such as their arguments or their subject.
            #   But from scope point of view, the child nodes are not in the parent's scope,
            #   they should be in the next outer scope.

            scanner.scope_stack.should == expected_scope_stack if expected_scope_stack
          end

          scanner.scan(ast, true)
        end
      end
    end
  end
end
