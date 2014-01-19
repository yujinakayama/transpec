# coding: utf-8

require 'ast'

module Transpec
  class Syntax
    module Mixin
      module AnyInstance
        include ::AST::Sexp

        def self.included(syntax)
          syntax.add_dynamic_analysis_request do |rewriter|
            key = :any_instance_target_class_name
            code = <<-END.gsub(/^\s+\|/, '').chomp
              |if self.class.name == 'RSpec::Mocks::AnyInstance::Recorder'
              |  if respond_to?(:klass)
              |    klass.name
              |  elsif instance_variable_defined?(:@klass)
              |    instance_variable_get(:@klass).name
              |  else
              |    nil
              |  end
              |else
              |  nil
              |end
            END
            rewriter.register_request(subject_node, key, code)
          end
        end

        def any_instance?
          return true unless any_instance_target_node.nil?
          node_data = runtime_node_data(subject_node)
          return false unless node_data && node_data[:any_instance_target_class_name]
          !node_data[:any_instance_target_class_name].result.nil?
        end

        def add_instance_arg_to_any_instance_implementation_block!
          return unless any_instance_block_node
          first_arg_node = any_instance_block_node.children[1].children[0]
          return unless first_arg_node
          first_arg_name = first_arg_node.children.first
          return if first_arg_name == :instance
          insert_before(first_arg_node.loc.expression, 'instance, ')

          @report.records << Record.new(
            "Klass.any_instance.#{method_name}(:message) { |arg| }",
            "Klass.any_instance.#{method_name}(:message) { |instance, arg| }"
          )
        end

        private

        def any_instance_block_node
          return unless any_instance?
          each_chained_method_node do |node, _|
            return node if node.block_type?
          end
        end

        def any_instance_target_class_source
          return nil unless any_instance?

          if any_instance_target_node
            any_instance_target_node.loc.expression.source
          else
            runtime_node_data(subject_node)[:any_instance_target_class_name].result
          end
        end

        def any_instance_target_node
          return nil unless subject_node.send_type?
          return nil unless subject_node.children.count == 2
          receiver_node, method_name = *subject_node
          return nil unless receiver_node
          return nil unless method_name == :any_instance

          if receiver_node.const_type? || receiver_node == s(:send, nil, :described_class)
            receiver_node
          else
            nil
          end
        end
      end
    end
  end
end
