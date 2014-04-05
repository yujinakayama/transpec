# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/monkey_patch'
require 'transpec/rspec_dsl'

module Transpec
  class Syntax
    class ExampleGroup < Syntax
      include Mixin::Send, Mixin::MonkeyPatch, RSpecDSL

      define_dynamic_analysis do |rewriter|
        code = "is_a?(Class) && ancestors.any? { |a| a.name == 'RSpec::Core::ExampleGroup' }"
        rewriter.register_request(node, :example_group_context?, code, :context)
      end

      def dynamic_analysis_target?
        super && receiver_node.nil? && EXAMPLE_GROUP_METHODS.include?(method_name)
      end

      def conversion_target?
        return false unless dynamic_analysis_target?

        if runtime_data.run?(node)
          # If we have runtime data, check with it.
          !runtime_data[node, :example_group_context?]
        else
          # Otherwise check statically.
          static_context_inspector.scopes.last != :example_group
        end
      end

      def convert_to_non_monkey_patch!
        insert_before(expression_range, 'RSpec.')
        register_record
      end

      def register_record
        original_syntax = method_name.to_s
        converted_syntax = "RSpec.#{method_name}"

        [original_syntax, converted_syntax].each do |syntax|
          syntax << " 'something' { }"
        end

        @report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
