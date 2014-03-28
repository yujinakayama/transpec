# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module AnyInstanceBlock
        extend ActiveSupport::Concern
        include Send

        def add_receiver_arg_to_any_instance_implementation_block!
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
          Util.each_backward_chained_node(node).find(&:block_type?)
        end

        class AnyInstanceBlockRecord < Record
          def initialize(host, *)
            @host = host
          end

          def build_original_syntax
            "#{base_syntax} { |arg| }"
          end

          def build_converted_syntax
            "#{base_syntax} { |instance, arg| }"
          end

          def base_syntax
            fail NotImplementedError
          end
        end

        class MonkeyPatchAnyInstanceBlockRecord < AnyInstanceBlockRecord
          def base_syntax
            "Klass.any_instance.#{@host.method_name}(:message)"
          end
        end
      end
    end
  end
end
