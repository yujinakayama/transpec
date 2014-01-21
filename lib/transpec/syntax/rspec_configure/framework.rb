# coding: utf-8

require 'transpec/util'
require 'ast'

module Transpec
  class Syntax
    class RSpecConfigure
      class Framework
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
      end
    end
  end
end

module Transpec
  class Syntax
    class RSpecConfigure
      class Framework
        include SyntaxConfiguration, Util, ::AST::Sexp

        def initialize(rspec_configure_node, source_rewriter)
          @rspec_configure_node = rspec_configure_node
          @source_rewriter = source_rewriter
        end

        private

        def framework_block_method_name
          fail NotImplementedError
        end

        def set_configuration!(config_name, value)
          setter_node = find_configuration_node("#{config_name}=")

          if setter_node
            arg_node = setter_node.children[2]
            @source_rewriter.replace(arg_node.loc.expression, value.to_s)
          else
            add_configuration!(config_name, value)
          end
        end

        def add_configuration!(config_name, value)
          block_arg_name = framework_block_arg_name || new_framework_block_arg_name

          lines = [framework_indentation + "#{block_arg_name}.#{config_name} = #{value}"]

          unless framework_block_node
            indentation = indentation_of_line(@rspec_configure_node) + '  '
            block_invocation = format(
              '%s.%s :rspec do |%s|',
              rspec_configure_block_arg_name, framework_block_method_name, block_arg_name
            )
            lines.unshift(indentation + block_invocation)
            lines << indentation + 'end'
          end

          block_node = framework_block_node || @rspec_configure_node
          insertion_position = beginning_of_line_range(block_node.loc.end)

          lines.unshift('') unless (block_node.loc.end.line - block_node.loc.begin.line) <= 1
          lines.map! { |line| line + "\n" }

          @source_rewriter.insert_before(insertion_position, lines.join(''))
        end

        def find_configuration_node(configuration_method_name)
          return nil unless framework_block_node

          configuration_method_name = configuration_method_name.to_sym

          framework_block_node.each_descendent_node.find do |node|
            next unless node.send_type?
            receiver_node, method_name, = *node
            next unless receiver_node == s(:lvar, framework_block_arg_name)
            method_name == configuration_method_name
          end
        end

        def framework_block_arg_name
          return nil unless framework_block_node
          first_block_arg_name(framework_block_node)
        end

        def framework_block_node
          return @framework_block_node if instance_variable_defined?(:@framework_block_node)

          @framework_block_node = @rspec_configure_node.each_descendent_node.find do |node|
            next unless node.block_type?
            send_node = node.children.first
            receiver_node, method_name, *_ = *send_node
            next unless receiver_node == s(:lvar, rspec_configure_block_arg_name)
            method_name == framework_block_method_name
            # TODO: Check expectation framework.
          end
        end

        def rspec_configure_block_arg_name
          first_block_arg_name(@rspec_configure_node)
        end

        def framework_indentation
          if framework_block_node
            indentation_of_line(framework_block_node) + '  '
          else
            indentation_of_line(@rspec_configure_node) + '    '
          end
        end

        def new_framework_block_arg_name
          case rspec_configure_block_arg_name
          when :rspec then self.class.name.split('::').last.downcase
          when :c     then 'config'
          else 'c'
          end
        end

        def first_block_arg_name(block_node)
          args_node = block_node.children[1]
          first_arg_node = args_node.children.first
          first_arg_node.children.first
        end
      end
    end
  end
end
