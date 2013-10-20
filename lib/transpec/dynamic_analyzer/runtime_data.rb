# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/ast/scanner'
require 'pathname'

module Transpec
  class DynamicAnalyzer
    class RuntimeData
      attr_reader :hash

      def initialize(hash = {})
        @hash = hash
      end

      def [](node)
        @hash[node_id(node)]
      end

      def node_id(node)
        source_range = node.loc.expression
        source_buffer = source_range.source_buffer
        absolute_path = File.expand_path(source_buffer.name)
        relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.pwd).to_s
        [relative_path, source_range.begin_pos, source_range.end_pos].join('_')
      end
    end
  end
end
