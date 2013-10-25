# coding: utf-8

require 'transpec/static_context_inspector'
require 'transpec/record'
require 'transpec/report'

module Transpec
  class Syntax
    attr_reader :node, :ancestor_nodes, :source_rewriter, :runtime_data, :report

    def self.inherited(subclass)
      all_syntaxes << subclass
    end

    def self.all_syntaxes
      @subclasses ||= []
    end

    def self.standalone_syntaxes
      @standalone_syntaxes ||= all_syntaxes.select(&:standalone?)
    end

    def self.standalone?
      true
    end

    def self.snake_case_name
      @snake_cake_name ||= begin
        class_name = name.split('::').last
        class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end
    end

    def self.register_request_for_dynamic_analysis(node, rewriter)
    end

    def self.target_node?(node, runtime_data = nil)
      false
    end

    def initialize(node, ancestor_nodes, source_rewriter = nil, runtime_data = nil, report = nil)
      @node = node
      @ancestor_nodes = ancestor_nodes
      @source_rewriter = source_rewriter
      @runtime_data = runtime_data
      @report = report || Report.new
    end

    def register_request_for_dynamic_analysis(rewriter)
    end

    def static_context_inspector
      @static_context_inspector ||= StaticContextInspector.new(@ancestor_nodes)
    end

    def parent_node
      @ancestor_nodes.last
    end

    def expression_range
      @node.loc.expression
    end

    private

    def runtime_node_data(node)
      @runtime_data && @runtime_data[node]
    end

    def remove(range)
      @source_rewriter.remove(range)
    end

    def insert_before(range, content)
      @source_rewriter.insert_before(range, content)
    end

    def insert_after(range, content)
      @source_rewriter.insert_after(range, content)
    end

    def replace(range, content)
      @source_rewriter.replace(range, content)
    end

    class InvalidContextError < StandardError
      attr_reader :message, :source_range

      def initialize(source_range, original_syntax, target_syntax)
        @source_range = source_range
        @message = build_message(original_syntax, target_syntax)
      end

      def source_buffer
        @source_range.source_buffer
      end

      private

      def build_message(original_syntax, target_syntax)
        "Cannot convert #{original_syntax} into #{target_syntax} " +
        "since #{target_syntax} is not available in the context."
      end
    end
  end
end
