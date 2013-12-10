# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/monkey_patch'
require 'transpec/syntax/mixin/expectizable'
require 'transpec/syntax/mixin/allow_no_message'
require 'transpec/syntax/mixin/any_instance'

module Transpec
  class Syntax
    class ShouldReceive < Syntax
      include Mixin::Send, Mixin::MonkeyPatch, Mixin::Expectizable, Mixin::AllowNoMessage,
              Mixin::AnyInstance

      alias_method :useless_expectation?, :allow_no_message?

      def self.target_method?(receiver_node, method_name)
        !receiver_node.nil? && [:should_receive, :should_not_receive].include?(method_name)
      end

      def register_request_for_dynamic_analysis(rewriter)
        super

        register_request_of_syntax_availability_inspection(
          rewriter,
          :expect_to_receive_available?,
          [:expect, :receive]
        )

        register_request_of_syntax_availability_inspection(
          rewriter,
          :allow_to_receive_available?,
          [:allow, :receive]
        )

        register_request_of_any_instance_inspection(rewriter)
      end

      def expect_to_receive_available?
        check_syntax_availability(__method__)
      end

      def allow_to_receive_available?
        check_syntax_availability(__method__)
      end

      def positive?
        method_name == :should_receive
      end

      def expectize!(negative_form = 'not_to')
        unless expect_to_receive_available?
          fail ContextError.new(selector_range, "##{method_name}", '#expect')
        end

        convert_to_syntax!('expect', negative_form)
        register_record(:expect, negative_form)
      end

      def allowize_useless_expectation!(negative_form = 'not_to')
        return unless useless_expectation?

        unless allow_to_receive_available?
          fail ContextError.new(selector_range, "##{method_name}", '#allow')
        end

        convert_to_syntax!('allow', negative_form)
        remove_allowance_for_no_message!

        register_record(:allow, negative_form)
      end

      def stubize_useless_expectation!
        return unless useless_expectation?

        replace(selector_range, 'stub')
        remove_allowance_for_no_message!

        register_record(:stub)
      end

      private

      def convert_to_syntax!(syntax, negative_form)
        if any_instance?
          wrap_subject_with_any_instance_of!(syntax)
        else
          wrap_subject_with_method!(syntax)
        end

        replace(selector_range, "#{positive? ? 'to' : negative_form} receive")

        correct_block_style!
      end

      def correct_block_style!
        return if broken_block_nodes.empty?

        broken_block_nodes.each do |block_node|
          map = block_node.loc
          next if map.begin.source == '{'
          replace(map.begin, '{')
          replace(map.end, '}')
        end
      end

      def wrap_subject_with_any_instance_of!(syntax)
        expression = "#{syntax}_any_instance_of(#{any_instance_target_class_source})"
        replace(subject_range, expression)
      end

      def broken_block_nodes
        @broken_block_nodes ||= [
          block_node_taken_by_with_method_with_no_normal_args,
          block_node_following_message_expectation_method
        ].compact.uniq
      end

      # subject.should_receive(:method_name).once.with do |block_arg|
      # end
      #
      # (block
      #   (send
      #     (send
      #       (send
      #         (send nil :subject) :should_receive
      #         (sym :method_name)) :once) :with)
      #   (args
      #     (arg :block_arg)) nil)
      def block_node_taken_by_with_method_with_no_normal_args
        each_following_chained_method_node do |chained_node, child_node|
          next unless chained_node.type == :block
          return nil unless child_node.children[1] == :with
          return nil if child_node.children[2]
          return chained_node
        end
      end

      # subject.should_receive(:method_name) do |block_arg|
      # end.once
      #
      # (send
      #   (block
      #     (send
      #       (send nil :subject) :should_receive
      #       (sym :method_name))
      #     (args
      #       (arg :block_arg)) nil) :once)
      def block_node_following_message_expectation_method
        each_following_chained_method_node do |chained_node, child_node|
          next unless chained_node.type == :send
          return child_node if child_node.type == :block
        end
      end

      def register_record(conversion_type, negative_form_of_to = nil)
        @report.records << Record.new(
          original_syntax(conversion_type),
          converted_syntax(conversion_type, negative_form_of_to)
        )
      end

      def original_syntax(conversion_type)
        syntax = if any_instance? && conversion_type != :stub
                  'Klass.any_instance.'
                 else
                  'obj.'
                 end

        syntax << (positive? ? 'should_receive' : 'should_not_receive')
        syntax << '(:message)'

        if [:allow, :stub].include?(conversion_type)
          syntax << '.any_number_of_times' if any_number_of_times?
          syntax << '.at_least(0)' if at_least_zero?
        end

        syntax
      end

      def converted_syntax(conversion_type, negative_form_of_to)
        return 'obj.stub(:message)' if conversion_type == :stub

        syntax = case conversion_type
                 when :expect
                   if any_instance?
                     'expect_any_instance_of(Klass).'
                   else
                     'expect(obj).'
                   end
                 when :allow
                   if any_instance?
                     'allow_any_instance_of(Klass).'
                   else
                     'allow(obj).'
                   end
                 end

        syntax << (positive? ? 'to' : negative_form_of_to)
        syntax << ' receive(:message)'
      end
    end
  end
end
