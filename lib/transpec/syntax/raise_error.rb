# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'

module Transpec
  class Syntax
    class RaiseError < Syntax
      include SendNodeSyntax

      def remove_error_specification_with_negative_expectation!
        return if positive?

        _receiver_node, _method_name, *arg_nodes = *node
        return if arg_nodes.empty?

        remove(parentheses_range)
      end

      def positive?
        expectation_method_name = parent_node.children[1]
        [:should, :to].include?(expectation_method_name)
      end

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:raise_error]
      end
    end
  end
end
