# coding: utf-8

require 'transpec/util'
require 'ast'

module Transpec
  class Syntax
    class RSpecConfigure
      module ConfigurationModification
        include Util, ::AST::Sexp

        def block_node
          fail NotImplementedError
        end

        private

        def set_configuration!(config_name, value)
          setter_node = find_configuration_node("#{config_name}=")

          if setter_node
            arg_node = setter_node.children[2]
            source_rewriter.replace(arg_node.loc.expression, value.to_s)
          else
            add_configuration!(config_name, value)
          end
        end

        def find_configuration_node(configuration_method_name)
          return nil unless block_node

          configuration_method_name = configuration_method_name.to_sym

          block_node.each_descendent_node.find do |node|
            next unless node.send_type?
            receiver_node, method_name, = *node
            next unless receiver_node == s(:lvar, block_arg_name)
            method_name == configuration_method_name
          end
        end

        def block_arg_name
          return nil unless block_node
          first_block_arg_name(block_node)
        end

        module ConfigurationAddition
          def add_configuration!(config_name, value)
            lines = generate_configuration_lines(config_name, value)
            lines.unshift('') unless empty_block_body?
            lines.map! { |line| line + "\n" }

            insertion_position = beginning_of_line_range(block_node_to_insert_code.loc.end)
            source_rewriter.insert_before(insertion_position, lines.join(''))

            block_node_to_insert_code.metadata[:added_configuration] = true
          end

          def generate_configuration_lines(config_name, value)
            [body_indentation + "#{config_variable_name}.#{config_name} = #{value}"]
          end

          def config_variable_name
            block_arg_name
          end

          def body_indentation
            indentation_of_line(block_node) + (' ' * 2)
          end

          def block_node_to_insert_code
            block_node
          end

          def empty_block_body?
            block_node = block_node_to_insert_code
            (block_node.loc.end.line - block_node.loc.begin.line <= 1) &&
              !block_node.metadata[:added_configuration]
          end
        end

        include ConfigurationAddition
      end
    end
  end
end
