# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/should_base'
require 'transpec/syntax/mixin/monkey_patch'
require 'transpec/syntax/mixin/expectizable'
require 'transpec/util'

module Transpec
  class Syntax
    class Should < Syntax
      include Mixin::ShouldBase, Mixin::MonkeyPatch, Mixin::Expectizable, Util

      attr_reader :current_syntax_type

      def self.target_method?(receiver_node, method_name)
        !receiver_node.nil? && [:should, :should_not].include?(method_name)
      end

      def initialize(node, source_rewriter = nil, runtime_data = nil, report = nil)
        super
        @current_syntax_type = :should
      end

      define_dynamic_analysis_request do |rewriter|
        register_request_of_syntax_availability_inspection(
          rewriter,
          :expect_available?,
          [:expect]
        )
      end

      def expect_available?
        check_syntax_availability(__method__)
      end

      def expectize!(negative_form = 'not_to', parenthesize_matcher_arg = true)
        fail ContextError.new(selector_range, "##{method_name}", '#expect') unless expect_available?

        if proc_literal?(subject_node)
          replace(range_of_subject_method_taking_block, 'expect')
        else
          wrap_subject_in_expect!
        end

        replace(should_range, positive? ? 'to' : negative_form)

        @current_syntax_type = :expect
        register_record(negative_form)

        operator_matcher.convert_operator!(parenthesize_matcher_arg) if operator_matcher
      end

      private

      def range_of_subject_method_taking_block
        send_node = subject_node.children.first
        send_node.loc.expression
      end

      def register_record(negative_form_of_to)
        if proc_literal?(subject_node)
          original_syntax = "#{range_of_subject_method_taking_block.source} { }.should"
          converted_syntax = 'expect { }.'
        else
          original_syntax = 'obj.should'
          converted_syntax = 'expect(obj).'
        end

        if positive?
          converted_syntax << 'to'
        else
          original_syntax << '_not'
          converted_syntax << negative_form_of_to
        end

        @report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
