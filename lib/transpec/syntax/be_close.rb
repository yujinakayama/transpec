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

        register_record
      end

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:be_close]
      end

      def register_record
        @report.records << Record.new('be_close(expected, delta)', 'be_within(delta).of(expected)')
      end
    end
  end
end
