# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    class Have < Syntax
      include Mixin::Send

      DEFAULT_QUERY_METHOD = 'size'.freeze

      def self.standalone?
        false
      end

      def self.conversion_target_method?(have_node, items_method_name)
        return false unless have_node
        have_receiver_node, have_method_name, *_ = *have_node
        return false if have_receiver_node
        [:have, :have_exactly, :have_at_least, :have_at_most].include?(have_method_name)
      end

      def initialize(node, expectation, source_rewriter = nil, runtime_data = nil, report = nil)
        @node = node
        @expectation = expectation
        @source_rewriter = source_rewriter
        @runtime_data = runtime_data
        @report = report || Report.new
      end

      def convert_to_standard_expectation!
        query_method = DEFAULT_QUERY_METHOD
        replace(@expectation.subject_range, "#{@expectation.subject_range.source}.#{query_method}")
        replace(expression_range, replacement_matcher_source(size_source))
        register_record(query_method)
      end

      def have_node
        node.children.first
      end

      def size_node
        have_node.children[2]
      end

      alias_method :items_node, :node

      def have_method_name
        have_node.children[1]
      end

      private

      def replacement_matcher_source(size_source)
        case @expectation.current_syntax_type
        when :should
          case have_method_name
          when :have, :have_exactly then "== #{size_source}"
          when :have_at_least       then ">= #{size_source}"
          when :have_at_most        then "<= #{size_source}"
          end
        when :expect
          case have_method_name
          when :have, :have_exactly then "eq(#{size_source})"
          when :have_at_least       then "be >= #{size_source}"
          when :have_at_most        then "be <= #{size_source}"
          end
        end
      end

      def size_source
        size_node.loc.expression.source
      end

      def dot_items_range
        map = items_node.loc
        map.dot.join(map.selector)
      end

      def register_record(query_method)
        @report.records << Record.new(original_syntax, converted_syntax(query_method))
      end

      def original_syntax
        syntax = case @expectation
                 when Should
                   'collection.should'
                 when Expect
                   'expect(collection).to'
                 end

        syntax << " #{have_method_name}(x).items"
      end

      def converted_syntax(query_method)
        syntax = case @expectation.current_syntax_type
                 when :should
                   "collection.#{query_method}.should"
                 when :expect
                   "expect(collection.#{query_method}).to"
                 end

        syntax << " #{replacement_matcher_source('x')}"
      end
    end
  end
end
