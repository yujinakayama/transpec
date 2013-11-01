# coding: utf-8

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

        private

        def any_number_of_times?
          !any_number_of_times_node.nil?
        end

        def at_least_zero?
          !at_least_zero_node.nil?
        end

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
          each_following_chained_method_node do |chained_node|
            method_name = chained_node.children[1]
            return chained_node if method_name == :any_number_of_times
          end
        end

        def at_least_zero_node
          each_following_chained_method_node do |chained_node|
            _, method_name, arg_node = *chained_node
            next unless method_name == :at_least
            return chained_node if arg_node == s(:int, 0)
          end
        end

        def each_following_chained_method_node
          return to_enum(__method__) unless block_given?

          @node.each_ancestor_node.reduce(@node) do |child_node, parent_node|
            return unless [:send, :block].include?(parent_node.type)
            return unless parent_node.children.first == child_node
            yield parent_node, child_node
            parent_node
          end
          nil
        end
      end
    end
  end
end
