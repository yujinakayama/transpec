# coding: utf-8

module Transpec
  module AST
    class ScopeStack < Array
      EXAMPLE_GROUP_METHOD_NAMES = [
        :describe, :context,
        :shared_examples, :shared_context, :share_examples_for, :shared_examples_for
      ].freeze

      def push_scope(node)
        push(scope_type(node))
      end

      def pop_scope
        pop
      end

      def in_example_group_context?
        if include?(:example_group)
          scopes_in_example_group = inner_scopes_in_scope(:example_group)
          return false if include_class_scope?(scopes_in_example_group)
          include_method_or_block_scope?(scopes_in_example_group)
        elsif include?(:rspec_configure)
          scopes_in_rspec_configure = inner_scopes_in_scope(:rspec_configure)
          return false if include_class_scope?(scopes_in_rspec_configure)
          include_method_or_block_scope?(scopes_in_rspec_configure)
        elsif first == :def
          scopes_in_method = self[1..-1]
          !include_class_scope?(scopes_in_method)
        elsif include?(:module)
          scopes_in_module = inner_scopes_in_scope(:module)
          return false if include_class_scope?(scopes_in_module)
          scopes_in_module.include?(:def)
        else
          false
        end
      end

      private

      def scope_type(node)
        return node.type unless node.type == :block

        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node

        if Util.const_name(receiver_node) == 'RSpec' && method_name == :configure
          :rspec_configure
        elsif receiver_node
          node.type
        elsif EXAMPLE_GROUP_METHOD_NAMES.include?(method_name)
          :example_group
        else
          node.type
        end
      end

      def inner_scopes_in_scope(scope_type)
        index = rindex(scope_type)
        return nil unless index
        self[Range.new(index + 1, -1)]
      end

      def include_class_scope?(scopes)
        !(scopes & [:class, :sclass]).empty?
      end

      def include_method_or_block_scope?(scopes)
        # TODO: Should validate whether the method taking the block is RSpec's
        #   special method. (e.g. #subject, #let, #before, #after)
        !(scopes & [:def, :block]).empty?
      end
    end
  end
end
