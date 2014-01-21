# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/receive_matcher_owner'
require 'transpec/util'

module Transpec
  class Syntax
    class Allow < Syntax
      include Mixin::Send, Mixin::ReceiveMatcherOwner, Util

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && [:allow, :allow_any_instance_of].include?(method_name)
      end

      def current_syntax_type
        :expect
      end

      def positive?
        to_method_name = parent_node.children[1]
        to_method_name == :to
      end

      def matcher_node
        to_arg_node = to_node.children[2]
        if to_arg_node.block_type?
          to_arg_node.children.first
        else
          to_arg_node
        end
      end

      def block_node
        block_node_taken_by_method(to_node)
      end

      alias_method :subject_node, :arg_node
      alias_method :to_node, :parent_node

      def subject_range
        subject_node.loc.expression
      end

      def any_instance?
        method_name == :allow_any_instance_of
      end
    end
  end
end
