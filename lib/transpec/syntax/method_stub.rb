# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/monkey_patch'
require 'transpec/syntax/mixin/allow_no_message'
require 'transpec/syntax/mixin/any_instance'
require 'transpec/util'
require 'English'

module Transpec
  class Syntax
    class MethodStub < Syntax
      include Mixin::Send, Mixin::MonkeyPatch, Mixin::AllowNoMessage, Mixin::AnyInstance, Util

      def self.target_method?(receiver_node, method_name)
        !receiver_node.nil? && [:stub, :unstub, :stub!, :unstub!].include?(method_name)
      end

      def allowize!
        # There's no way of unstubbing in #allow syntax.
        return unless [:stub, :stub!].include?(method_name)

        fail 'Already replaced deprecated method, cannot allowize.' if @replaced_deprecated_method

        unless context.allow_to_receive_available?
          fail InvalidContextError.new(selector_range, "##{method_name}", '#allow')
        end

        if arg_node.type == :hash
          expressions = build_allow_expressions_from_hash_node(arg_node)
          replace(expression_range, expressions)
        else
          expression = build_allow_expression(arg_node)
          replace(expression_range, expression)
        end

        register_record(:allow)

        @allowized = true
      end

      def replace_deprecated_method!
        return unless replacement_method_for_deprecated_method

        fail 'Already allowized, cannot replace deprecated method.' if @allowized

        replace(selector_range, replacement_method_for_deprecated_method)

        register_record(:deprecated)

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

      def replacement_method_for_deprecated_method
        case method_name
        when :stub!   then 'stub'
        when :unstub! then 'unstub'
        else nil
        end
      end

      def register_record(conversion_type)
        @report.records << Record.new(original_syntax, converted_syntax(conversion_type))
      end

      def original_syntax
        syntax = any_instance? ? 'SomeClass.any_instance' : 'obj'
        syntax << ".#{method_name}"
        syntax << (arg_node.type == :hash ? '(:message => value)' : '(:message)')
      end

      def converted_syntax(conversion_type)
        case conversion_type
        when :allow
          syntax = any_instance? ? 'allow_any_instance_of(SomeClass)' : 'allow(obj)'
          syntax << '.to receive(:message)'
          syntax << '.and_return(value)' if arg_node.type == :hash
        when :deprecated
          syntax = 'obj.'
          syntax << replacement_method_for_deprecated_method
          syntax << '(:message)'
        end

        syntax
      end
    end
  end
end
