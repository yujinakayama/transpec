# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/have_matcher_owner'
require 'transpec/syntax/operator_matcher'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module ShouldBase
        extend ActiveSupport::Concern
        include Send, HaveMatcherOwner

        included do
          define_dynamic_analysis_request do |rewriter|
            if OperatorMatcher.dynamic_analysis_target_node?(matcher_node)
              create_operator_matcher.register_request_for_dynamic_analysis(rewriter)
            end
          end
        end

        def positive?
          method_name == :should
        end

        def matcher_node
          if arg_node
            Util.each_forward_chained_node(arg_node, :include_origin)
              .select(&:send_type?).to_a.last
          else
            parent_node
          end
        end

        def should_range
          if arg_node
            selector_range
          else
            selector_range.join(expression_range.end)
          end
        end

        def operator_matcher
          return @operator_matcher if instance_variable_defined?(:@operator_matcher)

          @operator_matcher ||= begin
            if OperatorMatcher.conversion_target_node?(matcher_node, @runtime_data)
              create_operator_matcher
            else
              nil
            end
          end
        end

        private

        def create_operator_matcher
          OperatorMatcher.new(matcher_node, @source_rewriter, @runtime_data, @report)
        end
      end
    end
  end
end
