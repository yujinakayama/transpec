# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'

module Transpec
  class Syntax
    class Double < Syntax
      include SendNodeSyntax

      def convert_to_double!
        return if method_name == :double
        replace(selector_range, 'double')
        register_record
      end

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:double, :mock, :stub]
      end

      def register_record
        @report.records << Record.new("#{method_name}('something')", "double('something')")
      end
    end
  end
end
