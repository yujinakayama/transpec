# coding: utf-8

module Transpec
  module AST
    class Scanner
      attr_reader :context

      def self.scan(origin_node, &block)
        instance = new(&block)
        instance.scan(origin_node, true)
        nil
      end

      def initialize(&block)
        @callback = block
        @ancestor_nodes = []
      end

      def scan(origin_node, yield_origin_node = false)
        return unless origin_node

        yield_node(origin_node) if yield_origin_node

        @ancestor_nodes.push(origin_node)

        origin_node.each_child_node do |child_node|
          yield_node(child_node)
          scan(child_node)
        end

        @ancestor_nodes.pop
      end

      private

      def yield_node(node)
        @callback.call(node, @ancestor_nodes)
      end
    end
  end
end
