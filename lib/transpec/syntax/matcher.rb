# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class Matcher < Syntax
      include SendNodeSyntax, Util

      def self.target_node?(node)
        false
      end

      def initialize(node, in_example_group_context, source_rewriter)
        @node = node
        @in_example_group_context = in_example_group_context
        @source_rewriter = source_rewriter
      end

      def correct_operator!(parenthesize_arg = true)
        case method_name
        when :==
          replace(selector_range, 'eq')
          parenthesize!(parenthesize_arg)
        when :===, :<, :<=, :>, :>=
          insert_before(selector_range, 'be ')
        when :=~
          if arg_node.type == :array
            replace(selector_range, 'match_array')
          else
            replace(selector_range, 'match')
          end
          parenthesize!(parenthesize_arg)
        end
      end

      def parenthesize!(always = true)
        return if here_document?(arg_node)

        case left_parenthesis_range.source
        when ' '
          if always || arg_node.type == :hash
            replace(left_parenthesis_range, '(')
            insert_after(expression_range, ')')
          end
        when "\n", "\r"
          insert_before(left_parenthesis_range, '(')
          linefeed = left_parenthesis_range.source
          matcher_line_indentation = indentation_of_line(@node)
          right_parenthesis = "#{linefeed}#{matcher_line_indentation})"
          insert_after(expression_range, right_parenthesis)
        end
      end

      def convert_deprecated_method!
        return unless method_name == :be_close

        _receiver_node, _method_name, expected_node, delta_node = *node

        be_within_source = 'be_within('
        be_within_source << delta_node.loc.expression.source
        be_within_source << ').of('
        be_within_source << expected_node.loc.expression.source
        be_within_source << ')'

        replace(expression_range, be_within_source)
      end

      private

      def left_parenthesis_range
        Parser::Source::Range.new(
          selector_range.source_buffer,
          selector_range.end_pos,
          selector_range.end_pos + 1
        )
      end
    end
  end
end
