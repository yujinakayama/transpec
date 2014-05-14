# coding: utf-8

require 'transpec/util'
require 'ast'

module Transpec
  class Syntax
    class RSpecConfigure
      module ConfigModification
        include Util, ::AST::Sexp

        def block_node
          fail NotImplementedError
        end

        private

        def set_config!(config_name, value)
          setter_node = find_config_node("#{config_name}=")

          if setter_node
            arg_node = setter_node.children[2]
            source_rewriter.replace(arg_node.loc.expression, value.to_s)
          else
            add_config!(config_name, value)
          end
        end

        def find_config_node(config_method_name)
          return nil unless block_node

          config_method_name = config_method_name.to_sym

          block_node.each_descendent_node.find do |node|
            next unless node.send_type?
            receiver_node, method_name, = *node
            next unless receiver_node == s(:lvar, block_arg_name)
            method_name == config_method_name
          end
        end

        def block_arg_name
          return nil unless block_node
          first_block_arg_name(block_node)
        end

        # TODO: Refactor this to remove messy overrides in Framework.
        module ConfigAddition
          def add_config!(config_name, value = nil)
            lines = generate_config_lines(config_name, value)
            lines.unshift('') unless empty_block_body?
            lines.map! { |line| line + "\n" }

            insertion_position = beginning_of_line_range(block_node_to_insert_code.loc.end)
            source_rewriter.insert_before(insertion_position, lines.join(''))

            block_node_to_insert_code.metadata[:added_config] = true
          end

          def generate_config_lines(config_name, value = nil)
            line = body_indentation + "#{config_variable_name}.#{config_name}"
            line << " = #{value}" unless value.nil?
            [line]
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
              !block_node.metadata[:added_config]
          end
        end

        include ConfigAddition
      end
    end
  end
end
