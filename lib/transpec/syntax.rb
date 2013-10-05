# coding: utf-8

require 'transpec/context'
require 'transpec/report'
require 'transpec/record'

module Transpec
  class Syntax
    attr_reader :node, :ancestor_nodes, :source_rewriter, :report

    def self.all
      @subclasses ||= []
    end

    def self.inherited(subclass)
      all << subclass
    end

    def self.snake_case_name
      @snake_cake_name ||= begin
        class_name = name.split('::').last
        class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end
    end

    def self.target_node?(node)
      return false unless node.type == :send
      receiver_node, method_name, *_ = *node
      return false unless target_receiver_node?(receiver_node)
      target_method_names.include?(method_name)
    end

    def initialize(node, ancestor_nodes, source_rewriter, report = Report.new)
      @node = node
      @ancestor_nodes = ancestor_nodes
      @source_rewriter = source_rewriter
      @report = report
    end

    def context
      @context ||= Context.new(@ancestor_nodes)
    end

    def parent_node
      @ancestor_nodes.last
    end

    def expression_range
      @node.loc.expression
    end

    private

    def self.target_receiver_node?(node)
      false
    end

    def self.target_method_names
      []
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
