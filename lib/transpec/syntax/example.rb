# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/context_sensitive'
require 'transpec/rspec_dsl'

module Transpec
  class Syntax
    class Example < Syntax
      include Mixin::ContextSensitive, RSpecDSL

      def dynamic_analysis_target?
        super && receiver_node.nil? && EXAMPLE_METHODS.include?(method_name)
      end

      def should_be_in_example_group_context?
        true
      end

      def convert_pending_to_skip!
        convert_pending_selector_to_skip!
        convert_pending_metadata_to_skip!
      end

      def metadata_key_nodes
        metadata_nodes.each_with_object([]) do |node, key_nodes|
          if node.hash_type?
            key_nodes.concat(node.children.map { |pair_node| pair_node.children.first })
          else
            key_nodes << node
          end
        end
      end

      private

      def convert_pending_selector_to_skip!
        return unless method_name == :pending
        replace(selector_range, 'skip')
        register_record("pending 'is an example' { }", "skip 'is an example' { }")
      end

      def convert_pending_metadata_to_skip!
        metadata_key_nodes.each do |node|
          next unless pending_symbol?(node)
          replace(symbol_range_without_colon(node), 'skip')
          if node.parent_node.pair_type?
            register_record("it 'is an example', :pending => value { }",
                            "it 'is an example', :skip => value { }")
          else
            register_record("it 'is an example', :pending { }",
                            "it 'is an example', :skip { }")
          end
        end
      end

      def pending_symbol?(node)
        return false unless node.sym_type?
        key = node.children.first
        key == :pending
      end

      def symbol_range_without_colon(node)
        range = node.loc.expression
        if range.source.start_with?(':')
          Parser::Source::Range.new(range.source_buffer, range.begin_pos + 1, range.end_pos)
        else
          range
        end
      end

      def metadata_nodes
        arg_nodes[1..-1] || []
      end

      def register_record(original_syntax, converted_syntax)
        report.records << Record.new(original_syntax, converted_syntax)
      end
    end
  end
end
