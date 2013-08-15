# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/any_instanceable'
require 'transpec/util'
require 'English'

module Transpec
  class Syntax
    class MethodStub < Syntax
      include AnyInstanceable, Util

      def self.target_node?(node)
        return false unless node.type == :send
        receiver_node, method_name, *_ = *node
        return false unless receiver_node
        [:stub, :unstub, :stub!, :unstub!].include?(method_name)
      end

      def allowize!
        # There's no way of unstubbing in #allow syntax.
        return unless [:stub, :stub!].include?(method_name)

        fail 'Already replaced deprecated method, cannot allowize.' if @replaced_deprecated_method

        unless in_example_group_context?
          fail NotInExampleGroupContextError.new(expression_range, "##{method_name}", '#allow')
        end

        if arg_node.type == :hash
          expressions = build_allow_expressions_from_hash_node(arg_node)
          replace(expression_range, expressions)
        else
          expression = build_allow_expression(arg_node)
          replace(expression_range, expression)
        end

        @allowized = true
      end

      def replace_deprecated_method!
        replacement_method_name = case method_name
                                  when :stub!   then 'stub'
                                  when :unstub! then 'unstub'
                                  end

        return unless replacement_method_name

        fail 'Already allowized, cannot replace deprecated method.' if @allowized

        replace(selector_range, replacement_method_name)

        @replaced_deprecated_method = true
      end

      private

      def build_allow_expressions_from_hash_node(hash_node)
        expressions = []

        hash_node.children.each_with_index do |pair_node, index|
          key_node, value_node = *pair_node
          expression = build_allow_expression(key_node, value_node, false)
          expression.prepend(indentation_of_line(@node)) if index > 0
          expressions << expression
        end

        expressions.join($RS)
      end

      def build_allow_expression(message_node, return_value_node = nil, keep_form_around_arg = true)
        expression = ''

        expression << if any_instance?
                        class_source = class_node_of_any_instance.loc.expression.source
                        "allow_any_instance_of(#{class_source})"
                      else
                        "allow(#{subject_range.source})"
                      end

        expression << range_in_between_subject_and_selector.source
        expression << 'to receive'
        expression << (keep_form_around_arg ? range_in_between_selector_and_arg.source : '(')
        expression << message_source(message_node)
        expression << (keep_form_around_arg ? range_after_arg.source : ')')

        if return_value_node
          return_value_source = return_value_node.loc.expression.source
          expression << ".and_return(#{return_value_source})"
        end

        expression
      end

      def message_source(node)
        message_source = node.loc.expression.source
        message_source.prepend(':') if node.type == :sym && !message_source.start_with?(':')
        message_source
      end

      def range_in_between_subject_and_selector
        Parser::Source::Range.new(
          subject_range.source_buffer,
          subject_range.end_pos,
          selector_range.begin_pos
        )
      end

      def range_in_between_selector_and_arg
        Parser::Source::Range.new(
          selector_range.source_buffer,
          selector_range.end_pos,
          arg_range.begin_pos
        )
      end

      def range_after_arg
        Parser::Source::Range.new(
          arg_range.source_buffer,
          arg_range.end_pos,
          expression_range.end_pos
        )
      end
    end
  end
end
