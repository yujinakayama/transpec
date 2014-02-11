# coding: utf-8

require 'transpec/syntax/have'

module Transpec
  class Syntax
    class Have
      class DynamicInspector
        def self.register_request(have, rewriter)
          new(have, rewriter).register_request
        end

        attr_reader :have, :rewriter

        def initialize(have, rewriter)
          @have = have
          @rewriter = rewriter
        end

        def target_node
          if have.explicit_subject?
            have.expectation.subject_node
          else
            have.expectation.node
          end
        end

        def target_type
          if have.explicit_subject?
            :object
          else
            :context
          end
        end

        def register_request
          key = :collection_accessor
          code = collection_accessor_inspection_code
          rewriter.register_request(target_node, key, code, target_type)

          # Give up inspecting query methods of collection accessor with arguments
          # (e.g. have(2).errors_on(variable)) since this is a context of #instance_eval.
          unless have.items_method_has_arguments?
            key = :available_query_methods
            code = available_query_methods_inspection_code
            rewriter.register_request(target_node, key, code, target_type)
          end

          key = :collection_accessor_is_private?
          code = "#{subject_code}.private_methods.include?(#{have.items_name.inspect})"
          rewriter.register_request(target_node, key, code, target_type)

          key = :project_requires_collection_matcher?
          code = 'defined?(RSpec::Rails) || defined?(RSpec::CollectionMatchers)'
          rewriter.register_request(target_node, key, code, :context)
        end

        def subject_code
          have.explicit_subject? ? 'self' : 'subject'
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
            |  exact_name = #{have.items_name.inspect}
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
    end
  end
end
