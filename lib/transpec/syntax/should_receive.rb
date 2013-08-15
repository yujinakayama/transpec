# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/expectizable'
require 'transpec/syntax/any_instanceable'

module Transpec
  class Syntax
    class ShouldReceive < Syntax
      include Expectizable, AnyInstanceable

      def self.target_node?(node)
        return false unless node.type == :send
        receiver_node, method_name, *_ = *node
        return false unless receiver_node
        [:should_receive, :should_not_receive].include?(method_name)
      end

      def positive?
        method_name == :should_receive
      end

      def expectize!(negative_form = 'not_to')
        unless in_example_group_context?
          fail NotInExampleGroupContextError.new(expression_range, "##{method_name}", '#expect')
        end

        if any_instance?
          wrap_class_in_expect_any_instance_of!
        else
          wrap_subject_in_expect!
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

      private

      def wrap_class_in_expect_any_instance_of!
        insert_before(subject_range, 'expect_any_instance_of(')
        map = subject_node.loc
        dot_any_instance_range = map.dot.join(map.selector)
        replace(dot_any_instance_range, ')')
      end

      def broken_block_nodes
        @broken_block_nodes ||= [
          block_node_taken_by_with_method_with_no_normal_args,
          block_node_followed_by_message_expectation_method
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
        @ancestor_nodes.reverse.reduce(@node) do |child_node, parent_node|
          return nil unless [:send, :block].include?(parent_node.type)
          return nil unless parent_node.children.first == child_node

          if parent_node.type == :block
            return nil unless child_node.children[1] == :with
            return nil if child_node.children[2]
            return parent_node
          end

          parent_node
        end

        nil
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
      def block_node_followed_by_message_expectation_method
        @ancestor_nodes.reverse.reduce(@node) do |child_node, parent_node|
          return nil unless [:send, :block].include?(parent_node.type)
          return nil unless parent_node.children.first == child_node
          return child_node if child_node.type == :block && parent_node.type == :send
          parent_node
        end

        nil
      end
    end
  end
end
