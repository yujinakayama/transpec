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

        register_record
      end

      def positive?
        ancestor_nodes.reverse_each do |ancestor_node|
          next unless ancestor_node.type == :send
          expectation_method_name = ancestor_node.children[1]
          return [:should, :to].include?(expectation_method_name)
        end

        false
      end

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:raise_error]
      end

      def register_record
        original_syntax = 'expect { }.not_to raise_error('

        if arg_nodes.first.type == :const
          original_syntax << 'SpecificErrorClass'
          original_syntax << ', message' if arg_nodes.count >= 2
        else
          original_syntax << 'message'
        end

        original_syntax << ')'

        @report.records << Record.new(original_syntax, 'expect { }.not_to raise_error')
      end
    end
  end
end
