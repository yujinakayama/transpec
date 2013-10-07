# coding: utf-8

require 'transpec/syntax'
require 'transpec/util'
require 'transpec/ast/scanner'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      class FrameworkConfiguration
        include ::AST::Sexp

        def initialize(rspec_configure_node, framework_config_method_name, source_rewriter)
          @rspec_configure_node = rspec_configure_node
          @framework_config_method_name = framework_config_method_name
          @source_rewriter = source_rewriter
        end

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

        def modify_syntaxes!(syntaxes)
          unless [Array, Symbol].include?(syntaxes.class)
            fail ArgumentError, 'Syntaxes must be either an array or a symbol.'
          end

          @source_rewriter.replace(syntaxes_node.loc.expression, syntaxes.inspect)
        end

        private

        def syntaxes_node
          return nil unless framework_block_node

          @syntaxes_node ||= begin
            framework_config_variable_name = first_block_arg_name(framework_block_node)

            AST::Scanner.scan(framework_block_node) do |descendent_node|
              next unless descendent_node.type == :send
              receiver_node, method_name, arg_node, *_ = *descendent_node
              next unless receiver_node == s(:lvar, framework_config_variable_name)
              next unless method_name == :syntax=
              break arg_node
            end
          end
        end

        def framework_block_node
          @framework_block_node ||= begin
            AST::Scanner.scan(@rspec_configure_node) do |descendent_node|
              next unless descendent_node.type == :block
              send_node = descendent_node.children.first
              receiver_node, method_name, *_ = *send_node
              next unless receiver_node == s(:lvar, rspec_configure_block_arg_name)
              next unless method_name == @framework_config_method_name
              # TODO: Check expectation framework.
              break descendent_node
            end
          end
        end

        def rspec_configure_block_arg_name
          first_block_arg_name(@rspec_configure_node)
        end

        def first_block_arg_name(block_node)
          args_node = block_node.children[1]
          first_arg_node = args_node.children.first
          first_arg_node.children.first
        end
      end

      def self.target_node?(node)
        return false unless node.type == :block
        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node
        Util.const_name(receiver_node) == 'RSpec' && method_name == :configure
      end

      def self.add_framework_configuration(type, config_method_name)
        class_eval <<-END
          def #{type}_syntaxes
            #{type}_framework_configuration.syntaxes
          end

          def modify_#{type}_syntaxes!(syntaxes)
            #{type}_framework_configuration.modify_syntaxes!(syntaxes)
          end

          def #{type}_framework_configuration
            @#{type}_framework_configuration ||=
              FrameworkConfiguration.new(node, :#{config_method_name}, source_rewriter)
          end
        END
      end

      add_framework_configuration :expectation, :expect_with
      add_framework_configuration :mock,        :mock_with

      class UnknownSyntaxError < StandardError; end
    end
  end
end
