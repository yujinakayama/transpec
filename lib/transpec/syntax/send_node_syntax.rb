# coding: utf-8

require 'transpec/syntax'

module Transpec
  class Syntax
    module SendNodeSyntax
      def receiver_node
        @node.children[0]
      end

      alias_method :subject_node, :receiver_node

      def method_name
        @node.children[1]
      end

      def arg_node
        @node.children[2]
      end

      def expression_range
        @node.loc.expression
      end

      def selector_range
        @node.loc.selector
      end

      def receiver_range
        receiver_node.loc.expression
      end

      alias_method :subject_range, :receiver_range

      def arg_range
        arg_node.loc.expression
      end
    end
  end
end
