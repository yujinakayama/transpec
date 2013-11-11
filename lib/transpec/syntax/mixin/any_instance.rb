# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module AnyInstance
        include ::AST::Sexp

        def any_instance?
          !class_node_of_any_instance.nil?
        end

        def class_node_of_any_instance
          return nil unless subject_node.type == :send
          return nil unless subject_node.children.count == 2
          receiver_node, method_name = *subject_node
          return nil unless receiver_node
          return nil unless method_name == :any_instance

          if receiver_node.type == :const || receiver_node == s(:send, nil, :described_class)
            receiver_node
          else
            nil
          end
        end
      end
    end
  end
end
