# coding: utf-8

require 'active_support/concern'

module Transpec
  class Syntax
    module Mixin
      module OwnedMatcher
        extend ActiveSupport::Concern

        included do
          attr_reader :expectation
        end

        module ClassMethods
          def standalone?
            false
          end
        end

        def initialize(node, expectation, source_rewriter = nil, runtime_data = nil, report = nil)
          @node = node
          @expectation = expectation
          @source_rewriter = source_rewriter
          @runtime_data = runtime_data
          @report = report || Report.new
        end
      end
    end
  end
end
