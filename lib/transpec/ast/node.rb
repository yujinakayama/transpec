# coding: utf-8

require 'parser'

module Transpec
  module AST
    class Node < Parser::AST::Node
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
    end
  end
end
