# coding: utf-8

require 'active_support/concern'

module Transpec
  class Syntax
    module Mixin
      module MatcherOwner
        extend ActiveSupport::Concern

        module ClassMethods
          def add_matcher(matcher_class) # rubocop:disable MethodLength
            matcher_accessor_name = "#{matcher_class.snake_case_name}_matcher"
            matcher_ivar_name = "@#{matcher_accessor_name}"
            matcher_creator_name = "create_#{matcher_class.snake_case_name}"

            define_dynamic_analysis_request do |rewriter|
              if matcher_class.dynamic_analysis_target_node?(matcher_node)
                send(matcher_creator_name).register_request_for_dynamic_analysis(rewriter)
              end
            end

            define_method(matcher_accessor_name) do
              if instance_variable_defined?(matcher_ivar_name)
                return instance_variable_get(matcher_ivar_name)
              end

              if matcher_class.conversion_target_node?(matcher_node, runtime_data)
                instance_variable_set(matcher_ivar_name, send(matcher_creator_name))
              else
                instance_variable_set(matcher_ivar_name, nil)
              end
            end

            define_method(matcher_creator_name) do
              matcher_class.new(matcher_node, self, source_rewriter, runtime_data, report)
            end
          end
        end
      end
    end
  end
end
