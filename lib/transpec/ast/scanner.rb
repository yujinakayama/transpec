# coding: utf-8

require 'transpec/ast/scope_stack'
require 'parser'

module Transpec
  module AST
    class Scanner
      SCOPE_TYPES = [:module, :class, :sclass, :def, :defs, :block].freeze

      attr_reader :scope_stack

      def self.scan(origin_node, &block)
        instance = new(&block)
        instance.scan(origin_node, true)
      end

      def initialize(&block)
        @callback = block
        @ancestor_nodes = []
        @scope_stack = ScopeStack.new
      end

      def scan(origin_node, yield_origin_node = false)
        return unless origin_node

        yield_node(origin_node) if yield_origin_node

        @ancestor_nodes.push(origin_node)
        @scope_stack.push_scope(origin_node) if scope_node?(origin_node)

        origin_node.children.each_with_index do |child, index|
          next unless child.is_a?(Parser::AST::Node)
          node = child
          yield_node(node)
          scan(node)
        end

        @scope_stack.pop_scope if scope_node?(origin_node)
        @ancestor_nodes.pop
      end

      private

      def yield_node(node)
        @callback.call(node, @ancestor_nodes, @scope_stack.in_example_group_context?)
      end

      def scope_node?(node)
        SCOPE_TYPES.include?(node.type)
      end
    end
  end
end
