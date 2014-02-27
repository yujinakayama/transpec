# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/owned_matcher'

module Transpec
  class Syntax
    class Have < Syntax
      require 'transpec/syntax/have/dynamic_inspector'
      require 'transpec/syntax/have/source_builder'
      require 'transpec/syntax/have/have_record'

      include Mixin::Send, Mixin::OwnedMatcher

      # String#count is not query method, and there's no way to determine
      # whether a method is query method.
      # Method#arity and Method#parameters return same results
      # for Array#count (0+ args) and String#count (1+ args).
      #
      # So I make #size a priority over #count so that #count won't be chosen
      # for String (String responds to #size).
      QUERY_METHOD_PRIORITIES = [:size, :count, :length].freeze

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? &&
          [:have, :have_exactly, :have_at_least, :have_at_most].include?(method_name)
      end

      define_dynamic_analysis_request do |rewriter|
        DynamicInspector.register_request(self, rewriter)
      end

      def convert_to_standard_expectation!(parenthesize_matcher_arg = true)
        return if project_requires_collection_matcher?

        replace(expectation.subject_range, replacement_subject_source) if explicit_subject?
        replace(matcher_range, source_builder.replacement_matcher_source(parenthesize_matcher_arg))

        register_record if explicit_subject?
      end

      def explicit_subject?
        expectation.respond_to?(:subject_node)
      end

      alias_method :have_node, :node
      alias_method :items_node, :parent_node

      def size_node
        have_node.children[2]
      end

      def items_method_has_arguments?
        items_node.children.size > 2
      end

      def items_name
        items_node.children[1]
      end

      def project_requires_collection_matcher?
        runtime_subject_data && runtime_subject_data[:project_requires_collection_matcher?]
      end

      def collection_accessor
        if runtime_subject_data && runtime_subject_data[:collection_accessor]
          runtime_subject_data[:collection_accessor].to_sym
        else
          items_name
        end
      end

      def subject_is_owner_of_collection?
        return true if items_method_has_arguments?
        runtime_subject_data && !runtime_subject_data[:collection_accessor].nil?
      end

      def collection_accessor_is_private?
        runtime_subject_data && runtime_subject_data[:collection_accessor_is_private?]
      end

      def query_method
        if runtime_subject_data && runtime_subject_data[:available_query_methods]
          available_query_methods = runtime_subject_data[:available_query_methods]
          (QUERY_METHOD_PRIORITIES & available_query_methods.map(&:to_sym)).first
        else
          default_query_method
        end
      end

      def default_query_method
        QUERY_METHOD_PRIORITIES.first
      end

      def replacement_subject_source(base_subject = nil)
        base_subject ||= expectation.subject_node
        source_builder.replacement_subject_source(base_subject)
      end

      def size_source
        size_node.loc.expression.source
      end

      def accurate_conversion?
        !runtime_subject_data.nil?
      end

      def matcher_range
        expression_range.join(items_node.loc.expression)
      end

      private

      def source_builder
        @source_builder ||= SourceBuilder.new(self, size_source)
      end

      def runtime_subject_data
        return @runtime_subject_data if instance_variable_defined?(:@runtime_subject_data)
        node = explicit_subject? ? expectation.subject_node : expectation.node
        @runtime_subject_data = runtime_node_data(node)
      end

      def register_record
        report.records << HaveRecord.new(self)
      end
    end
  end
end
