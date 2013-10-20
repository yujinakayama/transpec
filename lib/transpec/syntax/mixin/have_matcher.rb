# coding: utf-8

require 'transpec/syntax/have'

module Transpec
  class Syntax
    module Mixin
      module HaveMatcher
        def have_matcher
          return @have_matcher if instance_variable_defined?(:@have_matcher)

          @have_matcher ||= begin
            if Have.target_node?(matcher_node, @runtime_data)
              Have.new(matcher_node, self, @source_rewriter, @runtime_data, @report)
            else
              nil
            end
          end
        end
      end
    end
  end
end
