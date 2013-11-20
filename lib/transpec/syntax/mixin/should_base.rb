# coding: utf-8

require 'transpec/syntax/operator_matcher'

module Transpec
  class Syntax
    module Mixin
      module ShouldBase
        def positive?
          method_name == :should
        end

        def matcher_node
          arg_node || parent_node
        end

        def operator_matcher
          return @operator_matcher if instance_variable_defined?(:@operator_matcher)

          @operator_matcher ||= begin
            if OperatorMatcher.target_node?(matcher_node, @runtime_data)
              OperatorMatcher.new(matcher_node, @source_rewriter, @runtime_data, @report)
            else
              nil
            end
          end
        end

        def should_range
          if arg_node
            selector_range
          else
            selector_range.join(expression_range.end)
          end
        end
      end
    end
  end
end
