# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module Send
        def self.included(klass)
          klass.extend(ClassMethods)
        end

        module ClassMethods
          def conversion_target_node?(node)
            return false unless node && node.type == :send
            receiver_node, method_name, *_ = *node
            conversion_target_method?(receiver_node, method_name)
          end

          def conversion_target_method?(receiver_node, method_name)
            false
          end
        end

        def receiver_node
          @node.children[0]
        end

        def method_name
          @node.children[1]
        end

        def arg_node
          @node.children[2]
        end

        def arg_nodes
          @node.children[2..-1]
        end

        def selector_range
          @node.loc.selector
        end

        def receiver_range
          receiver_node.loc.expression
        end

        def arg_range
          arg_node.loc.expression
        end

        def parentheses_range
          selector_range.end.join(expression_range.end)
        end

        def range_in_between_receiver_and_selector
          receiver_range.end.join(selector_range.begin)
        end

        def range_in_between_selector_and_arg
          selector_range.end.join(arg_range.begin)
        end

        def range_after_arg
          arg_range.end.join(expression_range.end)
        end
      end
    end
  end
end
