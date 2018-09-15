# coding: utf-8

require 'active_support/concern'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module Expectizable
        extend ActiveSupport::Concern

        def wrap_subject_in_expect!
          wrap_subject_with_method!('expect')
        end

        private

        def wrap_subject_with_method!(method)
          if Util.in_explicit_parentheses?(subject_node)
            insert_before(subject_range, method)
          else
            wrap(subject_range, "#{method}(", ')')
          end
        end
      end
    end
  end
end
