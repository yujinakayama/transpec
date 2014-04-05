# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/context_sensitive'
require 'transpec/syntax/mixin/monkey_patch'
require 'transpec/rspec_dsl'

module Transpec
  class Syntax
    class ExampleGroup < Syntax
      include Mixin::ContextSensitive, Mixin::MonkeyPatch, RSpecDSL

      def dynamic_analysis_target?
        super && receiver_node.nil? && EXAMPLE_GROUP_METHODS.include?(method_name)
      end

      def should_be_in_example_group_context?
        false
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
