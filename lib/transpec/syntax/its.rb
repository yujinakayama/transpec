# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/util'

module Transpec
  class Syntax
    class Its < Syntax
      include Mixin::Send, Util

      define_dynamic_analysis do |rewriter|
        key = :project_requires_its?
        code = 'defined?(RSpec::Its)'
        rewriter.register_request(node, key, code, :context)
      end

      def dynamic_analysis_target?
        super && receiver_node.nil? && method_name == :its
      end

      def conversion_target?
        super && !runtime_data[node, :project_requires_its?]
      end

      def convert_to_describe_subject_it!
        front, rear = build_wrapper_codes

        insert_before(beginning_of_line_range(block_node), front)
        replace(range_from_its_to_front_of_block, 'it ')
        insert_after(block_node.loc.expression, rear)

        add_record
      end

      def attribute_expression
        @attribute_expression ||= AttributeExpression.new(attribute_node)
      end

      def attributes
        attribute_expression.attributes
      end

      alias_method :attribute_node, :arg_node

      def block_node
        node.parent_node
      end

      private

      def build_wrapper_codes
        front = ''
        rear = ''

        front << "\n" if !previous_line_is_blank? &&
                         previous_and_current_line_are_same_indentation_level?

        attributes.each_with_index do |attribute, index|
          indentation = base_indentation + '  ' * index

          front << indentation + "describe #{attribute.description} do\n"
          front << indentation + "  subject { super#{attribute.selector} }\n\n"

          rear = "\n#{indentation}end" + rear
        end

        front << '  ' * attributes.size

        [front, rear]
      end

      def previous_line_is_blank?
        return false unless previous_line_source
        previous_line_source.empty? || previous_line_source.match(/\A\s*\Z/)
      end

      def previous_and_current_line_are_same_indentation_level?
        indentation_of_line(previous_line_source) == base_indentation
      end

      def previous_line_source
        expression_range.source_buffer.source_line(expression_range.line - 1)
      rescue IndexError
        nil
      end

      def base_indentation
        @base_indentation ||= indentation_of_line(node)
      end

      def range_from_its_to_front_of_block
        expression_range.join(block_node.loc.begin.begin)
      end

      def add_record
        report.records << Record.new(original_syntax, converted_syntax)
      end

      def original_syntax
        if attribute_expression.brackets?
          'its([:key]) { }'
        else
          'its(:attr) { }'
        end
      end

      def converted_syntax
        if attribute_expression.brackets?
          "describe '[:key]' do subject { super()[:key] }; it { } end"
        else
          "describe '#attr' do subject { super().attr }; it { } end"
        end
      end

      class AttributeExpression
        attr_reader :node

        def initialize(node)
          @node = node
        end

        def brackets?
          node.array_type?
        end

        def literal?
          Util.literal?(node)
        end

        def attributes
          @attributes ||= if brackets?
                            brackets_attributes
                          else
                            non_brackets_attributes
                          end
        end

        private

        def brackets_attributes
          selector = node.loc.expression.source
          description = literal? ? quote(selector) : selector
          [Attribute.new(selector, description)]
        end

        def non_brackets_attributes
          if literal?
            expression = node.children.first.to_s
            chained_names = expression.split('.')
            chained_names.map do |name|
              Attribute.new(".#{name}", quote("##{name}"))
            end
          else
            source = node.loc.expression.source
            selector = ".send(#{source})"
            [Attribute.new(selector, source)]
          end
        end

        def quote(string)
          if string.include?("'")
            '"' + string + '"'
          elsif string.include?('"')
            string.inspect
          else
            "'" + string + "'"
          end
        end
      end

      Attribute = Struct.new(:selector, :description)
    end
  end
end
