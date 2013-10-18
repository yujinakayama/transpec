# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module AnyInstance
        def any_instance?
          !class_node_of_any_instance.nil?
        end

        def class_node_of_any_instance
          return nil unless subject_node.type == :send
          return nil unless subject_node.children.count == 2
          receiver_node, method_name = *subject_node
          return nil unless method_name == :any_instance
          return nil unless receiver_node.type == :const
          receiver_node
        end
      end
    end
  end
end
