# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/util'
require 'ast'

module Transpec
  class Syntax
    class OperatorMatcher < Syntax
      include Mixin::Send, Util, ::AST::Sexp

      OPERATORS = [:==, :===, :<, :<=, :>, :>=, :=~].freeze

      def self.standalone?
        false
      end

      def self.target_method?(receiver_node, method_name)
        !receiver_node.nil? && OPERATORS.include?(method_name)
      end

      def register_request_for_dynamic_analysis(rewriter)
        return unless method_name == :=~
        rewriter.register_request(arg_node, :arg_is_enumerable?, 'is_a?(Enumerable)')
      end

      def convert_operator!(parenthesize_arg = true)
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
        return if contain_here_document?(arg_node)

        left_of_arg_source = range_in_between_selector_and_arg.source

        if left_of_arg_source.match(/\A *\Z/)
          parenthesize_single_line!(always)
        elsif left_of_arg_source.match(/\n|\r/)
          parenthesize_multi_line!(Regexp.last_match(0))
        end
      end

      private

      def convert_to_eq!(parenthesize_arg)
        handle_anterior_of_operator!
        replace(selector_range, 'eq')
        parenthesize!(parenthesize_arg)
        register_record(nil, 'eq(expected)')
      end

      def convert_to_be_operator!
        return if prefixed_with_be?
        insert_before(selector_range, 'be ')
        register_record(nil, "be #{method_name} expected")
      end

      def convert_to_match!(parenthesize_arg)
        handle_anterior_of_operator!

        if arg_is_enumerable?
          replace(selector_range, 'match_array')
        else
          replace(selector_range, 'match')
        end

        parenthesize!(parenthesize_arg)

        # Need to register record after all source rewrites are done
        # to avoid false record when failed with overlapped rewrite.
        if arg_is_enumerable?
          register_record('=~ [1, 2]', 'match_array([1, 2])')
        else
          register_record('=~ /pattern/', 'match(/pattern/)')
        end
      end

      def handle_anterior_of_operator!
        if prefixed_with_be?
          remove_be!
        elsif range_in_between_receiver_and_selector.source.empty?
          insert_before(selector_range, ' ')
        end
      end

      def arg_is_enumerable?
        return true if arg_node.type == :array
        node_data = runtime_node_data(arg_node)
        node_data && node_data[:arg_is_enumerable?].result
      end

      def parenthesize_single_line!(always)
        if in_parentheses?(arg_node)
          remove(range_in_between_selector_and_arg)
        elsif always || arg_node.type == :hash
          replace(range_in_between_selector_and_arg, '(')
          insert_after(expression_range, ')')
        elsif range_in_between_selector_and_arg.source.empty?
          insert_after(selector_range, ' ')
        end
      end

      def parenthesize_multi_line!(linefeed)
        insert_before(range_in_between_selector_and_arg, '(')
        matcher_line_indentation = indentation_of_line(@node)
        right_parenthesis = "#{linefeed}#{matcher_line_indentation})"
        insert_after(expression_range, right_parenthesis)
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

      def register_record(original_syntax, converted_syntax)
        original_syntax ||= "#{method_name} expected"
        @report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
