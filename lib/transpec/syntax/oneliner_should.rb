# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/should_base'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    class OnelinerShould < Syntax
      include Mixin::ShouldBase, Mixin::Send

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && [:should, :should_not].include?(method_name)
      end

      def expectize!(negative_form = 'not_to', parenthesize_matcher_arg = true)
        replacement = 'is_expected.'
        replacement << (positive? ? 'to' : negative_form)
        replace(should_range, replacement)
        register_record(negative_form)

        operator_matcher.convert_operator!(parenthesize_matcher_arg) if operator_matcher
      end

      private

      def register_record(negative_form_of_to)
        original_syntax = 'it { should'
        converted_syntax = 'it { is_expected.'

        if positive?
          converted_syntax << 'to'
        else
          original_syntax << '_not'
          converted_syntax << negative_form_of_to
        end

        [original_syntax, converted_syntax].each do |syntax|
          syntax << ' ... }'
        end

        @report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
