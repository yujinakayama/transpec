# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/have_matcher_owner'

module Transpec
  class Syntax
    class Expect < Syntax
      include Mixin::Send, Mixin::HaveMatcherOwner

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && method_name == :expect
      end

      def current_syntax_type
        :expect
      end

      def positive?
        to_method_name = parent_node.children[1]
        to_method_name == :to
      end

      def matcher_node
        parent_node.children[2]
      end

      alias_method :subject_node, :arg_node

      def subject_range
        subject_node.loc.expression
      end
    end
  end
end
