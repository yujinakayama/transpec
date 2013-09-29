# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/expectizable'
require 'transpec/syntax/matcher'
require 'transpec/util'

module Transpec
  class Syntax
    class Should < Syntax
      include Expectizable, Util

      def positive?
        method_name == :should
      end

      def expectize!(negative_form = 'not_to', parenthesize_matcher_arg = true)
        unless in_example_group_context?
          fail NotInExampleGroupContextError.new(selector_range, "##{method_name}", '#expect')
        end

        if proc_literal?(subject_node)
          replace_proc_selector_with_expect!
        else
          wrap_subject_in_expect!
        end

        replace(should_range, positive? ? 'to' : negative_form)

        matcher.correct_operator!(parenthesize_matcher_arg)
      end

      def matcher
        @matcher ||= Matcher.new(matcher_node, in_example_group_context?, @source_rewriter)
      end

      def matcher_node
        arg_node || parent_node
      end

      private

      def self.target_receiver_node?(node)
        !node.nil?
      end

      def self.target_method_names
        [:should, :should_not]
      end

      def replace_proc_selector_with_expect!
        send_node = subject_node.children.first
        range_of_subject_method_taking_block = send_node.loc.expression
        replace(range_of_subject_method_taking_block, 'expect')
      end

      def should_range
        if arg_node
          selector_range
        else
          selector_range.join(expression_range.end)
        end
      end
    end
  end
end
