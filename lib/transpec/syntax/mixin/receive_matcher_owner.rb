# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/receive'

module Transpec
  class Syntax
    module Mixin
      module ReceiveMatcherOwner
        extend ActiveSupport::Concern

        def self.included(syntax)
          syntax.add_dynamic_analysis_request do |rewriter|
            if Receive.dynamic_analysis_target_node?(matcher_node)
              create_receive_matcher.register_request_for_dynamic_analysis(rewriter)
            end
          end
        end

        def receive_matcher
          return @receive_matcher if instance_variable_defined?(:@receive_matcher)

          @receive_matcher ||= if Receive.conversion_target_node?(matcher_node, @runtime_data)
                                 create_receive_matcher
                               else
                                 nil
                               end
        end

        private

        def create_receive_matcher
          Receive.new(matcher_node, self, @source_rewriter, @runtime_data, @report)
        end
      end
    end
  end
end
