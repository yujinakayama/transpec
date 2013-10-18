# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/have_matcher'

module Transpec
  class Syntax
    class Expect < Syntax
      include Mixin::HaveMatcher

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

      private

      def self.target_receiver_node?(node)
        node.nil?
      end

      def self.target_method_names
        [:expect]
      end
    end
  end
end
