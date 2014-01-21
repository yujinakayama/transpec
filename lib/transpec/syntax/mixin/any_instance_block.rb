# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    module Mixin
      module AnyInstanceBlock
        extend ActiveSupport::Concern
        include Send

        def add_instance_arg_to_any_instance_implementation_block!
          return unless any_instance_block_node
          first_arg_node = any_instance_block_node.children[1].children[0]
          return unless first_arg_node
          first_arg_name = first_arg_node.children.first
          return if first_arg_name == :instance
          insert_before(first_arg_node.loc.expression, 'instance, ')
          true
        end

        private

        def any_instance_block_node
          return unless any_instance?
          each_chained_method_node do |node, _|
            return node if node.block_type?
          end
        end
      end
    end
  end
end
