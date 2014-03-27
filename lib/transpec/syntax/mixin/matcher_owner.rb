# coding: utf-8

require 'active_support/concern'

module Transpec
  class Syntax
    module Mixin
      module MatcherOwner
        extend ActiveSupport::Concern

        module ClassMethods
          def add_matcher(matcher_class) # rubocop:disable MethodLength
            matcher_accessor = "#{matcher_class.snake_case_name}_matcher"
            matcher_ivar = "@#{matcher_accessor}"
            matcher_creator = "create_#{matcher_class.snake_case_name}"

            define_dynamic_analysis_request do |rewriter|
              matcher = send(matcher_creator)
              if matcher.dynamic_analysis_target?
                matcher.register_request_for_dynamic_analysis(rewriter)
              end
            end

            define_method(matcher_accessor) do
              if instance_variable_defined?(matcher_ivar)
                return instance_variable_get(matcher_ivar)
              end

              matcher = send(matcher_creator)

              if matcher.conversion_target?
                instance_variable_set(matcher_ivar, matcher)
              else
                instance_variable_set(matcher_ivar, nil)
              end
            end

            define_method(matcher_creator) do
              matcher_class.new(matcher_node, self, source_rewriter, runtime_data, report)
            end
          end
        end
      end
    end
  end
end
