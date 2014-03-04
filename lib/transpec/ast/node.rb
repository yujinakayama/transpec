# coding: utf-8

require 'parser'

module Transpec
  module AST
    class Node < Parser::AST::Node
      attr_reader :metadata

      def initialize(type, children = [], properties = {})
        @metadata = {}
        @mutable_attributes = {}

        # ::AST::Node#initialize freezes itself.
        super

        each_child_node do |child_node|
          child_node.parent_node = self
        end
      end

      Parser::Meta::NODE_TYPES.each do |node_type|
        method_name = "#{node_type.to_s.gsub(/\W/, '')}_type?"
        define_method(method_name) do
          type == node_type
        end
      end

      def parent_node
        @mutable_attributes[:parent_node]
      end

      def parent_node=(node)
        @mutable_attributes[:parent_node] = node
      end

      protected :parent_node=

      def each_ancestor_node(&block)
        return to_enum(__method__) unless block_given?

        if parent_node
          yield parent_node
          parent_node.each_ancestor_node(&block)
        end

        self
      end

      def ancestor_nodes
        each_ancestor_node.to_a
      end

      def each_child_node
        return to_enum(__method__) unless block_given?

        children.each do |child|
          next unless child.is_a?(self.class)
          yield child
        end

        self
      end

      def child_nodes
        each_child_node.to_a
      end

      def each_descendent_node(&block)
        return to_enum(__method__) unless block_given?

        each_child_node do |child_node|
          yield child_node
          child_node.each_descendent_node(&block)
        end
      end

      def descendent_nodes
        each_descendent_node.to_a
      end

      def each_node(&block)
        return to_enum(__method__) unless block_given?
        yield self
        each_descendent_node(&block)
      end
    end
  end
end
