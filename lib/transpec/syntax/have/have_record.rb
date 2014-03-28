# coding: utf-8

require 'transpec/syntax/have'

module Transpec
  class Syntax
    class Have
      class HaveRecord < Record
        attr_reader :have

        def initialize(have)
          @have = have
        end

        def annotation
          return @annotation if instance_variable_defined?(:@annotation)

          @annotation = if have.accurate_conversion?
                          nil
                        else
                          AccuracyAnnotation.new(have.matcher_range)
                        end
        end

        private

        def build_original_syntax
          type = have.expectation.class.snake_case_name.to_sym
          syntax = build_expectation(original_subject, type)
          syntax << " #{have.method_name}(n).#{original_items}"
        end

        def build_converted_syntax
          type = have.expectation.current_syntax_type
          syntax = build_expectation(converted_subject, type)
          syntax << " #{source_builder.replacement_matcher_source}"
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
          have.expectation.positive?
        end

        def original_subject
          if have.subject_is_owner_of_collection?
            'obj'
          else
            'collection'
          end
        end

        def original_items
          if have.subject_is_owner_of_collection?
            if have.items_method_has_arguments?
              "#{have.collection_accessor}(...)"
            else
              have.collection_accessor
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
          if have.subject_is_owner_of_collection?
            converted_owner_of_collection(subject)
          else
            subject << ".#{have.default_query_method}"
          end
        end

        def converted_owner_of_collection(subject)
          subject << '.'

          if have.collection_accessor_is_private?
            subject << "send(#{have.collection_accessor.inspect}"
            subject << ', ...' if have.items_method_has_arguments?
            subject << ')'
          else
            subject << "#{have.collection_accessor}"
            subject << '(...)' if have.items_method_has_arguments?
          end

          subject << ".#{have.query_method}"
        end

        def source_builder
          @source_builder ||= SourceBuilder.new(have, 'n')
        end
      end
    end
  end
end
