# coding: utf-8

require 'transpec/util'
require 'ast'

module Transpec
  class Syntax
    class RSpecConfigure
      class Framework
        include Util, ::AST::Sexp

        attr_reader :rspec_configure, :source_rewriter

        def initialize(rspec_configure, source_rewriter)
          @rspec_configure = rspec_configure
          @source_rewriter = source_rewriter
        end

        private

        def block_method_name
          fail NotImplementedError
        end

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

        def block_node
          return @block_node if instance_variable_defined?(:@block_node)

          @block_node = rspec_configure.node.each_descendent_node.find do |node|
            next unless node.block_type?
            send_node = node.children.first
            receiver_node, method_name, *_ = *send_node
            next unless receiver_node == s(:lvar, rspec_configure.block_arg_name)
            method_name == block_method_name
            # TODO: Check expectation framework.
          end
        end

        module ConfigurationAddition
          def add_configuration!(config_name, value)
            lines = [body_indentation + "#{config_variable_name}.#{config_name} = #{value}"]

            unless block_node
              lines.unshift(framework_begin_code)
              lines << framework_end_code
            end

            lines.unshift('') unless empty_block_body?(block_node_to_insert_code)
            lines.map! { |line| line + "\n" }

            insertion_position = beginning_of_line_range(block_node_to_insert_code.loc.end)
            source_rewriter.insert_before(insertion_position, lines.join(''))
          end

          def config_variable_name
            block_arg_name || new_config_variable_name
          end

          def new_config_variable_name
            case rspec_configure.block_arg_name
            when :rspec then self.class.name.split('::').last.downcase
            when :c     then 'config'
            else 'c'
            end
          end

          def body_indentation
            if block_node
              indentation_of_line(block_node) + (' ' * 2)
            else
              indentation_of_line(rspec_configure.node) + (' ' * 4)
            end
          end

          def framework_begin_code
            code = format(
              '%s.%s :rspec do |%s|',
              rspec_configure.block_arg_name, block_method_name, config_variable_name
            )
            rspec_configure_body_indentation + code
          end

          def framework_end_code
            rspec_configure_body_indentation + 'end'
          end

          def rspec_configure_body_indentation
            indentation_of_line(rspec_configure.node) + (' ' * 2)
          end

          def block_node_to_insert_code
            block_node || rspec_configure.node
          end

          def empty_block_body?(block_node)
            (block_node.loc.end.line - block_node.loc.begin.line) <= 1
          end
        end

        include ConfigurationAddition

        module SyntaxConfiguration
          def syntaxes
            return [] unless syntaxes_node

            case syntaxes_node.type
            when :sym
              [syntaxes_node.children.first]
            when :array
              syntaxes_node.children.map do |child_node|
                child_node.children.first
              end
            else
              fail UnknownSyntaxError, "Unknown syntax specification: #{syntaxes_node}"
            end
          end

          def syntaxes=(syntaxes)
            unless [Array, Symbol].include?(syntaxes.class)
              fail ArgumentError, 'Syntaxes must be either an array or a symbol.'
            end

            set_configuration!(:syntax, syntaxes.inspect)
          end

          private

          def syntaxes_node
            return @syntaxes_node if instance_variable_defined?(:@syntaxes_node)

            syntax_setter_node = find_configuration_node(:syntax=)

            @syntaxes_node = if syntax_setter_node
                               syntax_setter_node.children[2]
                             else
                               nil
                             end
          end

          class UnknownSyntaxError < StandardError; end
        end

        include SyntaxConfiguration
      end
    end
  end
end
