# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'

module Transpec
  class Syntax
    class BeClose < Syntax
      def convert_to_be_within!
        _receiver_node, _method_name, expected_node, delta_node = *node

        be_within_source = 'be_within('
        be_within_source << delta_node.loc.expression.source
        be_within_source << ').of('
        be_within_source << expected_node.loc.expression.source
        be_within_source << ')'

        replace(expression_range, be_within_source)
      end

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:be_close]
      end
    end
  end
end
