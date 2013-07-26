# coding: utf-8

require 'transpec/syntax'

module Transpec
  class Syntax
    module AnyNumberOfTimesable
      def any_number_of_times?
        !any_number_of_times_node.nil?
      end

      def remove_any_number_of_times!
        return unless any_number_of_times?

        map = any_number_of_times_node.loc
        dot_any_number_of_times_range = map.dot.join(map.selector)
        remove(dot_any_number_of_times_range)
      end

      private

      def any_number_of_times_node
        each_following_chained_method_node do |chained_node|
          method_name = chained_node.children[1]
          return chained_node if method_name == :any_number_of_times
        end
      end

      def each_following_chained_method_node
        return to_enum(__method__) unless block_given?

        @ancestor_nodes.reverse.reduce(@node) do |child_node, parent_node|
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
