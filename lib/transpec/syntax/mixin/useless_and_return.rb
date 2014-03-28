# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module UselessAndReturn
        extend ActiveSupport::Concern
        include Send

        def remove_useless_and_return!
          return unless useless_and_return?
          map = and_return_node.loc
          and_return_range = map.dot.join(map.expression.end)
          remove(and_return_range)
          true
        end

        def useless_and_return?
          return false unless and_return?
          arg_node = and_return_node.children[2]
          arg_node.nil?
        end

        def and_return_with_block?
          block_node = Util.block_node_taken_by_method(and_return_node)
          !block_node.nil?
        end

        def and_return?
          !and_return_node.nil?
        end

        def and_return_node
          return @and_return_node if instance_variable_defined?(:@and_return_node)

          @and_return_node = Util.each_backward_chained_node(node) do |chained_node|
            method_name = chained_node.children[1]
            break chained_node if method_name == :and_return
          end
        end

        class UselessAndReturnRecord < Record
          def initialize(host, *)
            @host = host
          end

          def build_original_syntax
            syntax = base_syntax
            syntax << '.and_return'
            syntax << ' { value }' if @host.and_return_with_block?
            syntax
          end

          def build_converted_syntax
            syntax = base_syntax
            syntax << ' { value }' if @host.and_return_with_block?
            syntax
          end

          def base_syntax
            fail NotImplementedError
          end
        end

        class MonkeyPatchUselessAndReturnRecord < UselessAndReturnRecord
          def base_syntax
            "obj.#{@host.method_name}(:message)"
          end
        end
      end
    end
  end
end
