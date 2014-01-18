# coding: utf-8

require 'transpec/syntax/rspec_configure/framework'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure
      class Mocks < Framework
        include Util

        def yield_receiver_to_any_instance_implementation_blocks=(boolean)
          set_configuration!(:yield_receiver_to_any_instance_implementation_blocks, boolean)
        end

        private

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
              rspec_configure_block_arg_name, @framework_block_method_name, block_arg_name
            )
            lines.unshift(indentation + block_invocation)
            lines << indentation + 'end'
          end

          lines.map! { |line| line + "\n" }

          block_node = framework_block_node ? framework_block_node : @rspec_configure_node
          insertion_position = beginning_of_line_range(block_node.loc.end)
          @source_rewriter.insert_before(insertion_position, lines.join(''))
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
          when :rspec then 'mocks'
          when :c     then 'config'
          else 'c'
          end
        end
      end
    end
  end
end
