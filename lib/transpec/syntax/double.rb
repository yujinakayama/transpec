# coding: utf-8

require 'transpec/syntax'

module Transpec
  class Syntax
    class Double < Syntax
      def self.target_node?(node)
        return false unless node.type == :send
        receiver_node, method_name, *_ = *node
        return false if receiver_node
        [:double, :mock, :stub].include?(method_name)
      end

      def replace_deprecated_method!
        return if method_name == :double
        replace(selector_range, 'double')
      end
    end
  end
end
