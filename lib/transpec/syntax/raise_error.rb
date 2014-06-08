# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/owned_matcher'

module Transpec
  class Syntax
    class RaiseError < Syntax
      include Mixin::Send, Mixin::OwnedMatcher

      def dynamic_analysis_target?
        super && receiver_node.nil? && method_name == :raise_error
      end

      def remove_error_specification_with_negative_expectation!
        return if expectation.positive?

        _receiver_node, _method_name, *arg_nodes = *node
        return if arg_nodes.empty?

        remove(parentheses_range)

        add_record
      end

      private

      def add_record
        original_syntax = 'expect { }.not_to raise_error('

        if arg_nodes.first.const_type?
          original_syntax << 'SpecificErrorClass'
          original_syntax << ', message' if arg_nodes.count >= 2
        else
          original_syntax << 'message'
        end

        original_syntax << ')'

        report.records << Record.new(original_syntax, 'expect { }.not_to raise_error')
      end
    end
  end
end
