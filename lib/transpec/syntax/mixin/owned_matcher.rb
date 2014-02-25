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
          super(node, source_rewriter, runtime_data, report)
          @expectation = expectation
        end
      end
    end
  end
end
