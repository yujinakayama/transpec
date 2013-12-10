# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    class Have < Syntax
      include Mixin::Send

      # String#count is not query method, and there's no way to determine
      # whether a method is query method.
      # Method#arity and Method#parameters return same results
      # for Array#count (0+ args) and String#count (1+ args).
      #
      # So I make #size a priority over #count so that #count won't be chosen
      # for String (String responds to #size).
      QUERY_METHOD_PRIORITIES = [:size, :count, :length].freeze

      attr_reader :expectation

      def self.standalone?
        false
      end

      def self.target_method?(have_node, items_method_name)
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

      add_dynamic_analysis_request do |rewriter|
        DynamicInspector.register_request(self, rewriter)
      end

      def convert_to_standard_expectation!(parenthesize_matcher_arg = true)
        return if project_requires_collection_matcher?
        replace(@expectation.subject_range, replacement_subject_source) if explicit_subject?
        replace(expression_range, replacement_matcher_source(parenthesize_matcher_arg))
        register_record if explicit_subject?
      end

      def explicit_subject?
        @expectation.respond_to?(:subject_node)
      end

      def have_node
        node.children.first
      end

      def size_node
        have_node.children[2]
      end

      alias_method :items_node, :node

      def items_method_has_arguments?
        items_node.children.size > 2
      end

      def have_method_name
        have_node.children[1]
      end

      def items_name
        items_node.children[1]
      end

      def project_requires_collection_matcher?
        runtime_subject_data && runtime_subject_data[:project_requires_collection_matcher?].result
      end

      def collection_accessor
        if runtime_subject_data && runtime_subject_data[:collection_accessor].result
          runtime_subject_data[:collection_accessor].result.to_sym
        else
          items_name
        end
      end

      def subject_is_owner_of_collection?
        return true if items_method_has_arguments?
        runtime_subject_data && !runtime_subject_data[:collection_accessor].result.nil?
      end

      def collection_accessor_is_private?
        runtime_subject_data && runtime_subject_data[:collection_accessor_is_private?].result
      end

      def query_method
        if runtime_subject_data && runtime_subject_data[:available_query_methods]
          available_query_methods = runtime_subject_data[:available_query_methods].result
          (QUERY_METHOD_PRIORITIES & available_query_methods.map(&:to_sym)).first
        else
          default_query_method
        end
      end

      def default_query_method
        QUERY_METHOD_PRIORITIES.first
      end

      def replacement_subject_source
        build_replacement_subject_source(@expectation.subject_range.source)
      end

      def build_replacement_subject_source(original_subject_source)
        source = original_subject_source.dup
        if subject_is_owner_of_collection?
          if collection_accessor_is_private?
            source << ".send(#{collection_accessor.inspect}"
            source << ", #{args_range.source}" if items_method_has_arguments?
            source << ')'
          else
            source << ".#{collection_accessor}#{parentheses_range.source}"
          end
        end
        source << ".#{query_method}"
      end

      def replacement_matcher_source(parenthesize_arg)
        size_source = size_node.loc.expression.source
        build_replacement_matcher_source(size_source, parenthesize_arg)
      end

      def build_replacement_matcher_source(size_source, parenthesize_arg = true)
        case @expectation.current_syntax_type
        when :should
          build_replacement_matcher_source_for_should(size_source)
        when :expect
          build_replacement_matcher_source_for_expect(size_source, parenthesize_arg)
        end
      end

      def size_source
        size_node.loc.expression.source
      end

      private

      def runtime_subject_data
        return @runtime_subject_data if instance_variable_defined?(:@runtime_subject_data)
        node = explicit_subject? ? @expectation.subject_node : @expectation.node
        @runtime_subject_data = runtime_node_data(node)
      end

      def build_replacement_matcher_source_for_should(size_source)
        case have_method_name
        when :have, :have_exactly then "== #{size_source}"
        when :have_at_least       then ">= #{size_source}"
        when :have_at_most        then "<= #{size_source}"
        end
      end

      def build_replacement_matcher_source_for_expect(size_source, parenthesize_arg)
        case have_method_name
        when :have, :have_exactly
          if parenthesize_arg
            "eq(#{size_source})"
          else
            "eq #{size_source}"
          end
        when :have_at_least
          "be >= #{size_source}"
        when :have_at_most
          "be <= #{size_source}"
        end
      end

      def register_record
        @report.records << HaveRecord.new(self)
      end

      class DynamicInspector
        def self.register_request(have, rewriter)
          new(have, rewriter).register_request
        end

        def initialize(have, rewriter)
          @have = have
          @rewriter = rewriter
        end

        def target_node
          if @have.explicit_subject?
            @have.expectation.subject_node
          else
            @have.expectation.node
          end
        end

        def target_type
          if @have.explicit_subject?
            :object
          else
            :context
          end
        end

        def register_request
          key = :collection_accessor
          code = collection_accessor_inspection_code
          @rewriter.register_request(target_node, key, code, target_type)

          # Give up inspecting query methods of collection accessor with arguments
          # (e.g. have(2).errors_on(variable)) since this is a context of #instance_eval.
          unless @have.items_method_has_arguments?
            key = :available_query_methods
            code = available_query_methods_inspection_code
            @rewriter.register_request(target_node, key, code, target_type)
          end

          key = :collection_accessor_is_private?
          code = "#{subject_code}.private_methods.include?(#{@have.items_name.inspect})"
          @rewriter.register_request(target_node, key, code, target_type)

          key = :project_requires_collection_matcher?
          code = 'defined?(RSpec::Rails) || defined?(RSpec::CollectionMatchers)'
          @rewriter.register_request(target_node, key, code, :context)
        end

        def subject_code
          @have.explicit_subject? ? 'self' : 'subject'
        end

        # rubocop:disable MethodLength
        def collection_accessor_inspection_code
          # `expect(owner).to have(n).things` invokes private owner#things with Object#__send__
          # if the owner does not respond to any of #size, #count and #length.
          #
          # rubocop:disable LineLength
          # https://github.com/rspec/rspec-expectations/blob/v2.14.3/lib/rspec/matchers/built_in/have.rb#L48-L58
          # rubocop:enable LineLength
          @collection_accessor_inspection_code ||= <<-END.gsub(/^\s+\|/, '').chomp
            |begin
            |  exact_name = #{@have.items_name.inspect}
            |
            |  inflector = if defined?(ActiveSupport::Inflector) &&
            |                   ActiveSupport::Inflector.respond_to?(:pluralize)
            |                ActiveSupport::Inflector
            |              elsif defined?(Inflector)
            |                Inflector
            |              else
            |                nil
            |              end
            |
            |  if inflector
            |    pluralized_name = inflector.pluralize(exact_name).to_sym
            |    respond_to_pluralized_name = #{subject_code}.respond_to?(pluralized_name)
            |  end
            |
            |  respond_to_query_methods =
            |    !(#{subject_code}.methods & #{QUERY_METHOD_PRIORITIES.inspect}).empty?
            |
            |  if #{subject_code}.respond_to?(exact_name)
            |    exact_name
            |  elsif respond_to_pluralized_name
            |    pluralized_name
            |  elsif respond_to_query_methods
            |    nil
            |  else
            |    exact_name
            |  end
            |end
          END
        end
        # rubocop:enable MethodLength

        def available_query_methods_inspection_code
          <<-END.gsub(/^\s+\|/, '').chomp
            |collection_accessor = #{collection_accessor_inspection_code}
            |target = if collection_accessor
            |           #{subject_code}.__send__(collection_accessor)
            |         else
            |           #{subject_code}
            |         end
            |target.methods & #{QUERY_METHOD_PRIORITIES.inspect}
          END
        end
      end

      class HaveRecord < Record
        def initialize(have)
          @have = have
        end

        def original_syntax
          @original_syntax ||= begin
            type = @have.expectation.class.snake_case_name.to_sym
            syntax = build_expectation(original_subject, type)
            syntax << " #{@have.have_method_name}(n).#{original_items}"
          end
        end

        def converted_syntax
          @converted_syntax ||= begin
            type = @have.expectation.current_syntax_type
            syntax = build_expectation(converted_subject, type)
            syntax << " #{@have.build_replacement_matcher_source('n')}"
          end
        end

        def build_expectation(subject, type)
          case type
          when :should
            syntax = "#{subject}.should"
            syntax << '_not' unless positive?
          when :expect
            syntax = "expect(#{subject})."
            syntax << (positive? ? 'to' : 'not_to')
          end

          syntax
        end

        def positive?
          @have.expectation.positive?
        end

        def original_subject
          if @have.subject_is_owner_of_collection?
            'obj'
          else
            'collection'
          end
        end

        def original_items
          if @have.subject_is_owner_of_collection?
            if @have.items_method_has_arguments?
              "#{@have.collection_accessor}(...)"
            else
              @have.collection_accessor
            end
          else
            'items'
          end
        end

        def converted_subject
          if @have.subject_is_owner_of_collection?
            build_converted_subject('obj')
          else
            build_converted_subject('collection')
          end
        end

        def build_converted_subject(subject)
          subject << '.'

          if @have.subject_is_owner_of_collection?
            if @have.collection_accessor_is_private?
              subject << "send(#{@have.collection_accessor.inspect}"
              subject << ', ...' if @have.items_method_has_arguments?
              subject << ')'
            else
              subject << "#{@have.collection_accessor}"
              subject << '(...)' if @have.items_method_has_arguments?
            end
            subject << ".#{@have.query_method}"
          else
            subject << "#{@have.default_query_method}"
          end
        end
      end
    end
  end
end
