# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/matcher_owner'
require 'transpec/syntax/receive'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module ExpectBase
        extend ActiveSupport::Concern
        include Send, MatcherOwner

        included do
          add_matcher Receive
          alias_method :subject_node, :arg_node
          alias_method :to_node, :parent_node
        end

        def current_syntax_type
          :expect
        end

        def method_name_for_instance
          fail NotImplementedError
        end

        def positive?
          to_method_name = to_node.children[1]
          to_method_name == :to
        end

        def matcher_node
          to_arg_node = to_node.children[2]
          Util.each_forward_chained_node(to_arg_node, :include_origin)
            .select(&:send_type?).to_a.last
        end

        def block_node
          Util.block_node_taken_by_method(to_node)
        end

        def subject_range
          subject_node.loc.expression
        end
      end
    end
  end
end
