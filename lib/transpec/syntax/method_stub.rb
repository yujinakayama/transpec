# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/able_to_allow_no_message'
require 'transpec/syntax/able_to_target_any_instance'
require 'transpec/util'
require 'English'

module Transpec
  class Syntax
    class MethodStub < Syntax
      include AbleToAllowNoMessage, AbleToTargetAnyInstance, Util

      CLASSES_DEFINING_OWN_STUB_METHOD = [
        'Typhoeus', # https://github.com/typhoeus/typhoeus/blob/6a59c62/lib/typhoeus.rb#L66-L85
        'Excon'     # https://github.com/geemus/excon/blob/6af4f9c/lib/excon.rb#L143-L178
      ]

      def allowize!
        # There's no way of unstubbing in #allow syntax.
        return unless [:stub, :stub!].include?(method_name)

        fail 'Already replaced deprecated method, cannot allowize.' if @replaced_deprecated_method

        unless context.in_example_group?
          fail NotInExampleGroupContextError.new(selector_range, "##{method_name}", '#allow')
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

      def self.target_receiver_node?(node)
        return false if node.nil?
        const_name = Util.const_name(node)
        !CLASSES_DEFINING_OWN_STUB_METHOD.include?(const_name)
      end

      def self.target_method_names
        [:stub, :unstub, :stub!, :unstub!]
      end

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
        expression =  allow_source
        expression << range_in_between_receiver_and_selector.source
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

      def allow_source
        if any_instance?
          class_source = class_node_of_any_instance.loc.expression.source
          "allow_any_instance_of(#{class_source})"
        else
          "allow(#{subject_range.source})"
        end
      end

      def message_source(node)
        message_source = node.loc.expression.source
        message_source.prepend(':') if node.type == :sym && !message_source.start_with?(':')
        message_source
      end
    end
  end
end
