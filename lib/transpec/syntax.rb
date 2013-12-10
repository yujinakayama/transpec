# coding: utf-8

require 'transpec/context_error'
require 'transpec/static_context_inspector'
require 'transpec/record'
require 'transpec/report'

module Transpec
  class Syntax
    module Collection
      def inherited(subclass)
        all_syntaxes << subclass
      end

      def all_syntaxes
        @subclasses ||= []
      end

      def standalone_syntaxes
        @standalone_syntaxes ||= all_syntaxes.select(&:standalone?)
      end
    end
  end
end

module Transpec
  class Syntax
    module Rewritable
      private

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
    end
  end
end

module Transpec
  class Syntax
    extend Collection
    include Rewritable

    attr_reader :node, :source_rewriter, :runtime_data, :report

    def self.standalone?
      true
    end

    def self.snake_case_name
      @snake_cake_name ||= begin
        class_name = name.split('::').last
        class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end
    end

    def self.target_node?(node, runtime_data = nil)
      false
    end

    def initialize(node, source_rewriter = nil, runtime_data = nil, report = nil)
      @node = node
      @source_rewriter = source_rewriter
      @runtime_data = runtime_data
      @report = report || Report.new
    end

    def register_request_for_dynamic_analysis(rewriter)
    end

    def static_context_inspector
      @static_context_inspector ||= StaticContextInspector.new(@node)
    end

    def parent_node
      @node.parent_node
    end

    def expression_range
      @node.loc.expression
    end

    private

    def runtime_node_data(node)
      @runtime_data && @runtime_data[node]
    end
  end
end
