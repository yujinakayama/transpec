# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/have_matcher'

module Transpec
  class Syntax
    class Expect < Syntax
      include Mixin::Send, Mixin::HaveMatcher

      def self.conversion_target_method?(receiver_node, method_name)
        receiver_node.nil? && method_name == :expect
      end

      def register_request_for_dynamic_analysis(rewriter)
        have_matcher.register_request_for_dynamic_analysis(rewriter) if have_matcher
      end

      def current_syntax_type
        :expect
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
