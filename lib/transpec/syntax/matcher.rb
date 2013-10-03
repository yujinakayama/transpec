# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/send_node_syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class Matcher < Syntax
      include SendNodeSyntax, Util, ::AST::Sexp

      def self.target_node?(node)
        false
      end

      def initialize(node, source_rewriter)
        @node = node
        @source_rewriter = source_rewriter
      end

      def correct_operator!(parenthesize_arg = true)
        case method_name
        when :==
          convert_to_eq!(parenthesize_arg)
        when :===, :<, :<=, :>, :>=
          convert_to_be_operator!
        when :=~
          convert_to_match!(parenthesize_arg)
        end
      end

      def parenthesize!(always = true)
        return if argument_is_here_document?

        case left_parenthesis_range.source
        when ' '
          if in_parentheses?(arg_node)
            remove(left_parenthesis_range)
          elsif always || arg_node.type == :hash
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

      private

      def convert_to_eq!(parenthesize_arg)
        remove_be! if prefixed_with_be?
        replace(selector_range, 'eq')
        parenthesize!(parenthesize_arg)
      end

      def convert_to_be_operator!
        return if prefixed_with_be?
        insert_before(selector_range, 'be ')
      end

      def convert_to_match!(parenthesize_arg)
        remove_be! if prefixed_with_be?

        if arg_node.type == :array
          replace(selector_range, 'match_array')
        else
          replace(selector_range, 'match')
        end

        parenthesize!(parenthesize_arg)
      end

      def prefixed_with_be?
        !be_node.nil?
      end

      def remove_be!
        be_range = be_node.loc.expression.join(selector_range.begin)
        remove(be_range)
      end

      def be_node
        if receiver_node == s(:send, nil, :be)
          receiver_node
        else
          nil
        end
      end

      def argument_is_here_document?
        here_document?(arg_node) ||
          arg_node.each_descendent_node.any? { |n| here_document?(n) }
      end

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
