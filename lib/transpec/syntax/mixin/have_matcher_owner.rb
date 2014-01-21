# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/have'

module Transpec
  class Syntax
    module Mixin
      module HaveMatcherOwner
        extend ActiveSupport::Concern

        def self.included(syntax)
          syntax.add_dynamic_analysis_request do |rewriter|
            if Have.dynamic_analysis_target_node?(matcher_node)
              create_have_matcher.register_request_for_dynamic_analysis(rewriter)
            end
          end
        end

        def have_matcher # rubocop:disable PredicateName
          return @have_matcher if instance_variable_defined?(:@have_matcher)

          @have_matcher ||= if Have.conversion_target_node?(matcher_node, @runtime_data)
                              create_have_matcher
                            else
                              nil
                            end
        end

        private

        def create_have_matcher
          Have.new(matcher_node, self, @source_rewriter, @runtime_data, @report)
        end
      end
    end
  end
end
