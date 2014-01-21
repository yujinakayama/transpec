# coding: utf-8

require 'ast'

module Transpec
  class Syntax
    module Mixin
      module AllowNoMessage
        include ::AST::Sexp

        def allow_no_message?
          any_number_of_times? || at_least_zero?
        end

        def remove_allowance_for_no_message!
          remove_any_number_of_times!
          remove_at_least_zero!
        end

        def any_number_of_times?
          !any_number_of_times_node.nil?
        end

        def at_least_zero?
          !at_least_zero_node.nil?
        end

        private

        def remove_any_number_of_times!
          return unless any_number_of_times?
          remove_dot_and_method!(any_number_of_times_node)
        end

        def remove_at_least_zero!
          return unless at_least_zero?
          remove_dot_and_method!(at_least_zero_node)
        end

        def remove_dot_and_method!(send_node)
          map = send_node.loc
          dot_and_method_range = map.dot.join(map.expression.end)
          remove(dot_and_method_range)
        end

        def any_number_of_times_node
          each_chained_method_node do |chained_node|
            method_name = chained_node.children[1]
            return chained_node if method_name == :any_number_of_times
          end
        end

        def at_least_zero_node
          each_chained_method_node do |chained_node|
            _, method_name, arg_node = *chained_node
            next unless method_name == :at_least
            return chained_node if arg_node == s(:int, 0)
          end
        end
      end
    end
  end
end
