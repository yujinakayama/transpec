# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    class Double < Syntax
      include Mixin::Send

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && [:double, :mock, :stub].include?(method_name)
      end

      def convert_to_double!
        return if method_name == :double
        replace(selector_range, 'double')
        register_record
      end

      private

      def register_record
        @report.records << Record.new("#{method_name}('something')", "double('something')")
      end
    end
  end
end
