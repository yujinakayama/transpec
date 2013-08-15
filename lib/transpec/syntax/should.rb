# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'
require 'transpec/syntax/matcher'

module Transpec
  class Syntax
    class Should < Syntax
      include SendNodeSyntax, Util

      def self.target_node?(node)
        return false unless node.type == :send
        receiver_node, method_name, *_ = *node
        return false unless receiver_node
        [:should, :should_not].include?(method_name)
      end

      def positive?
        method_name == :should
      end

      def expectize!(negative_form = 'not_to', parenthesize_matcher_arg = true)
        unless in_example_group_context?
          fail NotInExampleGroupContextError.new(expression_range, "##{method_name}", '#expect')
        end

        if proc_literal?(subject_node)
          replace_proc_selector_with_expect!
        else
          wrap_subject_in_expect!
        end

        replace(selector_range, positive? ? 'to' : negative_form)

        matcher.correct_operator!(parenthesize_matcher_arg)
      end

      def matcher
        @matcher ||= Matcher.new(matcher_node, in_example_group_context?, @source_rewriter)
      end

      def matcher_node
        arg_node || parent_node
      end

      private

      def replace_proc_selector_with_expect!
        send_node = subject_node.children.first
        range_of_subject_method_taking_block = send_node.loc.expression
        replace(range_of_subject_method_taking_block, 'expect')
      end

      def wrap_subject_in_expect!
        if subject_range.source[0] == '('
          insert_before(subject_range, 'expect')
        else
          insert_before(subject_range, 'expect(')
          insert_after(subject_range, ')')
        end
      end
    end
  end
end
