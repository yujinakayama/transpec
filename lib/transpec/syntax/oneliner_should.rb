# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/should_base'
require 'transpec/rspec_dsl'
require 'transpec/util'
require 'active_support/inflector/methods'

module Transpec
  class Syntax
    class OnelinerShould < Syntax
      include Mixin::ShouldBase, RSpecDSL, Util

      attr_reader :current_syntax_type

      def initialize(*)
        super
        @current_syntax_type = :should
      end

      def dynamic_analysis_target?
        super && receiver_node.nil? && [:should, :should_not].include?(method_name)
      end

      def expectize!(negative_form = 'not_to')
        replacement = 'is_expected.'
        replacement << (positive? ? 'to' : negative_form)
        replace(should_range, replacement)

        @current_syntax_type = :expect

        register_record(negative_form)
      end

      def convert_have_items_to_standard_should!
        return unless have_matcher.conversion_target?

        insert_example_description!

        subject_source = have_matcher.replacement_subject_source('subject')
        insert_before(expression_range, "#{subject_source}.")

        have_matcher.convert_to_standard_expectation!

        report.records << OnelinerShouldHaveRecord.new(self, have_matcher)
      end

      def convert_have_items_to_standard_expect!(negative_form = 'not_to')
        return unless have_matcher.conversion_target?

        insert_example_description!

        subject_source = have_matcher.replacement_subject_source('subject')
        expect_to_source = "expect(#{subject_source})."
        expect_to_source << (positive? ? 'to' : negative_form)
        replace(should_range, expect_to_source)

        @current_syntax_type = :expect
        have_matcher.convert_to_standard_expectation!

        report.records << OnelinerShouldHaveRecord.new(self, have_matcher, negative_form)
      end

      def example_has_description?
        send_node = example_block_node.children.first
        send_node.children[2]
      end

      def build_description(size)
        description = positive? ? 'has ' : 'does not have '

        case have_matcher.method_name
        when :have_at_least then description << 'at least '
        when :have_at_most  then description << 'at most '
        end

        items = have_matcher.items_name

        if positive? && size == '0'
          size = 'no'
        elsif size == '1'
          items = ActiveSupport::Inflector.singularize(have_matcher.items_name)
        end

        description << "#{size} #{items}"
      end

      private

      def insert_example_description!
        unless have_matcher.conversion_target?
          fail 'This one-liner #should does not have #have matcher!'
        end

        unless example_has_description?
          insert_before(example_block_node.loc.begin, "'#{generated_description}' ")
        end

        indentation = indentation_of_line(example_block_node)

        unless linefeed_at_beginning_of_block?
          replace(left_curly_and_whitespaces_range, "do\n#{indentation}  ")
        end

        unless linefeed_at_end_of_block?
          replace(whitespaces_and_right_curly_range, "\n#{indentation}end")
        end
      end

      def example_block_node
        return @example_block_node if instance_variable_defined?(:@example_block_node)

        @example_block_node = node.each_ancestor_node.find do |node|
          next false unless node.block_type?
          send_node = node.children.first
          receiver_node, method_name, = *send_node
          next false if receiver_node
          EXAMPLE_METHODS.include?(method_name)
        end
      end

      def generated_description
        build_description(have_matcher.size_source)
      end

      def linefeed_at_beginning_of_block?
        beginning_to_body_range = example_block_node.loc.begin.join(expression_range.begin)
        beginning_to_body_range.source.include?("\n")
      end

      def linefeed_at_end_of_block?
        body_to_end_range = expression_range.end.join(example_block_node.loc.end)
        body_to_end_range.source.include?("\n")
      end

      def left_curly_and_whitespaces_range
        expand_range_to_adjacent_whitespaces(example_block_node.loc.begin, :end)
      end

      def whitespaces_and_right_curly_range
        expand_range_to_adjacent_whitespaces(example_block_node.loc.end, :begin)
      end

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

        report.records << Record.new(original_syntax, converted_syntax)
      end

      class OnelinerShouldHaveRecord < Have::HaveRecord
        attr_reader :should, :negative_form_of_to

        def initialize(should, have, negative_form_of_to = nil)
          super(have)
          @should = should
          @negative_form_of_to = negative_form_of_to
        end

        private

        def build_original_syntax
          syntax = should.example_has_description? ? "it '...' do" : 'it {'
          syntax << " #{should.method_name} #{have.method_name}(n).#{original_items} "
          syntax << (should.example_has_description? ? 'end' : '}')
        end

        def build_converted_syntax
          syntax = converted_description
          syntax << ' '
          syntax << converted_expectation
          syntax << ' '
          syntax << source_builder.replacement_matcher_source
          syntax << ' end'
        end

        def converted_description
          if should.example_has_description?
            "it '...' do"
          else
            "it '#{should.build_description('n')}' do"
          end
        end

        def converted_expectation
          case should.current_syntax_type
          when :should
            "#{converted_subject}.#{should.method_name}"
          when :expect
            "expect(#{converted_subject})." + (should.positive? ? 'to' : negative_form_of_to)
          end
        end

        def converted_subject
          build_converted_subject('subject')
        end
      end
    end
  end
end
