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
        !receiver_node.nil? && [:stub, :stub!, :stub_chain, :unstub, :unstub!].include?(method_name)
      end

      def register_request_for_dynamic_analysis(rewriter)
        super
        register_request_of_syntax_availability_inspection(
          rewriter,
          :allow_to_receive_available?,
          [:allow, :receive]
        )
        register_request_of_any_instance_inspection(rewriter)
      end

      def allow_to_receive_available?
        check_syntax_availability(__method__)
      end

      def allowize!(rspec_version)
        # There's no way of unstubbing in #allow syntax.
        return unless [:stub, :stub!, :stub_chain].include?(method_name)
        return if method_name == :stub_chain && !rspec_version.receive_message_chain_available?

        unless allow_to_receive_available?
          fail ContextError.new(selector_range, "##{method_name}", '#allow')
        end

        source, type = replacement_source_and_conversion_type(rspec_version)
        return unless source

        replace(expression_range, source)

        register_record(type)
      end

      def convert_deprecated_method!
        return unless replacement_method_for_deprecated_method

        replace(selector_range, replacement_method_for_deprecated_method)

        register_record(:deprecated)
      end

      private

      def replacement_source_and_conversion_type(rspec_version)
        if method_name == :stub_chain
          [build_allow_to(:receive_message_chain), :allow_to_receive_message_chain]
        else
          if arg_node.type == :hash
            if rspec_version.receive_messages_available?
              [build_allow_to(:receive_messages), :allow_to_receive_messages]
            else
              [build_multiple_allow_to_receive_with_hash(arg_node), :allow_to_receive]
            end
          else
            [build_allow_to_receive(arg_node), :allow_to_receive]
          end
        end
      end

      def build_multiple_allow_to_receive_with_hash(hash_node)
        expressions = []

        hash_node.children.each_with_index do |pair_node, index|
          key_node, value_node = *pair_node
          expression = build_allow_to_receive(key_node, value_node, false)
          expression.prepend(indentation_of_line(@node)) if index > 0
          expressions << expression
        end

        expressions.join($RS)
      end

      def build_allow_to_receive(message_node, value_node = nil, keep_form_around_arg = true)
        expression =  allow_source
        expression << range_in_between_receiver_and_selector.source
        expression << 'to receive'
        expression << (keep_form_around_arg ? range_in_between_selector_and_arg.source : '(')
        expression << message_source(message_node)
        expression << (keep_form_around_arg ? range_after_arg.source : ')')
        expression << ".and_return(#{value_node.loc.expression.source})" if value_node
        expression
      end

      def build_allow_to(method)
        expression =  allow_source
        expression << range_in_between_receiver_and_selector.source
        expression << "to #{method}"
        expression << parentheses_range.source
        expression
      end

      def allow_source
        if any_instance?
          "allow_any_instance_of(#{any_instance_target_class_source})"
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
        syntax = any_instance? ? 'Klass.any_instance' : 'obj'
        syntax << ".#{method_name}"

        if method_name == :stub_chain
          syntax << '(:message1, :message2)'
        else
          syntax << (arg_node.type == :hash ? '(:message => value)' : '(:message)')
        end
      end

      def converted_syntax(conversion_type)
        if conversion_type == :deprecated
          converted_syntax_from_deprecated
        else
          allowized_syntax(conversion_type)
        end
      end

      def allowized_syntax(conversion_type)
        syntax = any_instance? ? 'allow_any_instance_of(Klass)' : 'allow(obj)'
        syntax << '.to '

        case conversion_type
        when :allow_to_receive
          syntax << 'receive(:message)'
          syntax << '.and_return(value)' if arg_node.type == :hash
        when :allow_to_receive_messages
          syntax << 'receive_messages(:message => value)'
        when :allow_to_receive_message_chain
          syntax << 'receive_message_chain(:message1, :message2)'
        end

        syntax
      end

      def converted_syntax_from_deprecated
        syntax = 'obj.'
        syntax << replacement_method_for_deprecated_method
        syntax << '(:message)'
      end
    end
  end
end
