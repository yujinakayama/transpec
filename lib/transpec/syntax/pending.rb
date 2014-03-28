# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/util'

module Transpec
  class Syntax
    class Pending < Syntax
      include Mixin::Send, Util

      define_dynamic_analysis do |rewriter|
        code = 'is_a?(RSpec::Core::ExampleGroup)'
        rewriter.register_request(node, :example_context?, code, :context)
      end

      def dynamic_analysis_target?
        super && receiver_node.nil? && method_name == :pending
      end

      def conversion_target?
        return false unless dynamic_analysis_target?

        # Check whether the context is example group to differenciate
        # RSpec::Core::ExampleGroup.pending (a relative of #it) and
        # RSpec::Core::ExampleGroup#pending (marks the example as pending in #it block).
        if runtime_data.run?(node)
          # If we have runtime data, check with it.
          runtime_data[node, :example_context?]
        else
          # Otherwise check statically.
          static_context_inspector.scopes.last == :example
        end
      end

      def convert_deprecated_syntax!
        if block_node
          unblock!
        else
          convert_to_skip!
        end
      end

      private

      def convert_to_skip!
        replace(selector_range, 'skip')
        register_record('pending', 'skip')
      end

      def unblock!
        if block_beginning_line == block_body_line
          range_between_pending_and_body =
            expression_range.end.join(block_body_node.loc.expression.begin)
          replace(range_between_pending_and_body, "\n" + indentation_of_line(node))
        else
          remove(expression_range.end.join(block_node.loc.begin))
          outdent!(block_body_node, node)
        end

        if block_body_line == block_end_line
          remove(block_body_node.loc.expression.end.join(block_node.loc.end))
        else
          remove(line_range(block_node.loc.end))
        end

        register_record('pending { do_something_fail }', 'pending; do_something_fail')
      end

      def outdent!(target_node, base_node)
        indentation_width = indentation_width(target_node, base_node)

        return unless indentation_width > 0

        each_line_range(target_node) do |line_range|
          remove(line_range.resize(indentation_width))
        end
      end

      def indentation_width(target, base)
        indentation_of_line(target).size - indentation_of_line(base).size
      end

      def block_node
        block_node_taken_by_method(node)
      end

      def block_body_node
        block_node.children[2]
      end

      def block_beginning_line
        block_node.loc.begin.line
      end

      def block_body_line
        block_body_node.loc.expression.line
      end

      def block_end_line
        block_node.loc.end.line
      end

      def register_record(original_syntax, converted_syntax)
        report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
