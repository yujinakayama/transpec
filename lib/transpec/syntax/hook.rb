# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/rspec_dsl'

module Transpec
  class Syntax
    class Hook < Syntax
      include Mixin::Send, RSpecDSL

      SCOPE_ALIASES = {
        each: :example,
         all: :context
      }

      def dynamic_analysis_target?
        super && HOOK_METHODS.include?(method_name)
      end

      def convert_scope_name!
        return if !scope_name || !replacement_scope_name
        replace(arg_range, replacement_scope_name.inspect)
        add_record
      end

      private

      def scope_name
        return nil unless arg_node
        arg_node.children.first
      end

      def replacement_scope_name
        SCOPE_ALIASES[scope_name]
      end

      def add_record
        original_syntax = "#{method_name}(#{scope_name.inspect}) { }"
        converted_syntax = "#{method_name}(#{replacement_scope_name.inspect}) { }"
        report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
