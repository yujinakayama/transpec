# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/ast/scanner'

module Transpec
  class DynamicAnalyzer
    class Rewriter < BaseRewriter
      def process(ast, source_rewriter)
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless target_node?(node, ancestor_nodes)
          process_node(node, source_rewriter)
        end
      end

      def target_node?(node, ancestor_nodes)
        Syntax.all.any? do |syntax_class|
          syntax_class.dynamic_analysis_target_node?(node, ancestor_nodes)
        end
      end

      def process_node(node, source_rewriter)
        source_range = node.loc.expression

        source_rewriter.insert_before(source_range, 'transpec_analysis(')

        source_rewriter.insert_after(
          source_range,
          format(', self, __FILE__, %d, %d)', source_range.line, source_range.column)
        )
      rescue OverlappedRewriteError # rubocop:disable HandleExceptions
      end
    end
  end
end
