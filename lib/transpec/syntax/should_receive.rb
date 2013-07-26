# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/expectizable'
require 'transpec/syntax/any_instanceable'
require 'transpec/syntax/any_number_of_timesable'

module Transpec
  class Syntax
    class ShouldReceive < Syntax
      include Expectizable, AnyInstanceable, AnyNumberOfTimesable

      def positive?
        method_name == :should_receive
      end

      def expectize!(negative_form = 'not_to')
        convert_to_syntax!('expect', negative_form)
      end

      def allowize_any_number_of_times!(negative_form = 'not_to')
        return unless any_number_of_times?

        convert_to_syntax!('allow', negative_form)
        remove_any_number_of_times!
      end

      def stubize_any_number_of_times!(negative_form = 'not_to')
        return unless any_number_of_times?

        replace(selector_range, 'stub')
        remove_any_number_of_times!
      end

      private

      def convert_to_syntax!(syntax, negative_form)
        unless in_example_group_context?
          fail NotInExampleGroupContextError.new(expression_range, "##{method_name}", "##{syntax}")
        end

        if any_instance?
          wrap_class_in_expect_any_instance_of!
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

      def self.target_receiver_node?(node)
        !node.nil?
      end

      def self.target_method_names
        [:should_receive, :should_not_receive]
      end

      def wrap_class_in_expect_any_instance_of!
        insert_before(subject_range, 'expect_any_instance_of(')
        map = subject_node.loc
        dot_any_instance_range = map.dot.join(map.selector)
        replace(dot_any_instance_range, ')')
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
    end
  end
end
