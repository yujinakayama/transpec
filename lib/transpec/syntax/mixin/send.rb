# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module Send
        def self.included(klass)
          klass.extend(ClassMethods)
        end

        module ClassMethods
          def register_request_for_dynamic_analysis(node, rewriter)
            return unless target_node?(node)

            receiver_node, method_name, *_ = *node

            if receiver_node
              target_node = receiver_node
              target_object_type = :object
            else
              target_node = node
              target_object_type = :context
            end

            key = source_location_key(method_name)
            code = "method(#{method_name.inspect}).source_location"
            rewriter.register_request(target_node, key, code, target_object_type)
          end

          def target_node?(node, runtime_data = nil)
            check_target_node_statically(node) && check_target_node_dynamically(node, runtime_data)
          end

          def target_method?(receiver_node, method_name)
            false
          end

          def check_target_node_statically(node)
            return false unless node && node.type == :send
            receiver_node, method_name, *_ = *node
            target_method?(receiver_node, method_name)
          end

          def check_target_node_dynamically(node, runtime_data)
            return true unless runtime_data

            receiver_node, method_name, *_ = *node
            target_node = receiver_node ? receiver_node : node

            return true unless (node_data = runtime_data[target_node])
            return true unless (eval_data = node_data[source_location_key(method_name)])
            return true unless (source_location = eval_data.result)

            file_path = source_location.first
            !file_path.match(%r{/gems/rspec\-[^/]+/lib/rspec/}).nil?
          end

          def source_location_key(method_name)
            "#{method_name}_source_location".to_sym
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
