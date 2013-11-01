# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/util'

module Transpec
  class DynamicAnalyzer
    class Rewriter < BaseRewriter
      include Util

      def process(ast, source_rewriter)
        # TODO: Currently multitheading is not considered...
        clear_requests!
        collect_requests(ast)
        process_requests(source_rewriter)
      end

      def requests
        @requests ||= {}
      end

      def clear_requests!
        @requests = nil
      end

      def register_request(node, key, instance_eval_string, eval_target_type = :object)
        unless EVAL_TARGET_TYPES.include?(eval_target_type)
          fail "Target type must be any of #{EVAL_TARGET_TYPES}"
        end

        requests[node] ||= {}
        requests[node][key] = [eval_target_type, instance_eval_string]
      end

      private

      def collect_requests(ast)
        return unless ast

        ast.each_node do |node|
          Syntax.standalone_syntaxes.each do |syntax_class|
            syntax_class.register_request_for_dynamic_analysis(node, self)
            next unless syntax_class.target_node?(node)
            syntax = syntax_class.new(node)
            syntax.register_request_for_dynamic_analysis(self)
          end
        end
      end

      def process_requests(source_rewriter)
        requests.each do |node, analysis_codes|
          inject_analysis_method(node, analysis_codes, source_rewriter)
        end
      end

      def inject_analysis_method(node, analysis_codes, source_rewriter)
        front, rear = build_wrapper_codes(node, analysis_codes)

        source_range = if taking_block?(node)
                         node.parent_node.loc.expression
                       else
                         node.loc.expression
                       end

        source_rewriter.insert_before(source_range, front)
        source_rewriter.insert_after(source_range, rear)
      rescue OverlappedRewriteError # rubocop:disable HandleExceptions
      end

      def build_wrapper_codes(node, analysis_codes)
        source_range = node.loc.expression

        front = "#{ANALYSIS_METHOD}(("

        rear = format(
          '), self, %s, __FILE__, %d, %d)',
          hash_literal(analysis_codes), source_range.begin_pos, source_range.end_pos
        )
        rear = "\n" + indentation_of_line(source_range.end) + rear if contain_here_document?(node)

        [front, rear]
      end

      # Hash#inspect generates invalid literal with following example:
      #
      # > eval({ :predicate? => 1 }.inspect)
      # SyntaxError: (eval):1: syntax error, unexpected =>
      # {:predicate?=>1}
      #               ^
      def hash_literal(hash)
        literal = '{ '

        hash.each_with_index do |(key, value), index|
          literal << ', ' unless index == 0
          literal << "#{key.inspect} => #{value.inspect}"
        end

        literal << ' }'
      end

      def taking_block?(node)
        parent_node = node.parent_node
        parent_node && parent_node.type == :block && parent_node.children.first.equal?(node)
      end
    end
  end
end
