# coding: utf-8

require 'transpec/syntax/send_node_syntax'
require 'transpec/util'

module Transpec
  class Syntax
    module Expectizable
      include SendNodeSyntax

      def wrap_subject_in_expect!
        wrap_subject_with_method!('expect')
      end

      private

      def wrap_subject_with_method!(method)
        if Util.in_parentheses?(subject_node)
          insert_before(subject_range, method)
        else
          insert_before(subject_range, "#{method}(")
          insert_after(subject_range, ')')
        end
      end
    end
  end
end
