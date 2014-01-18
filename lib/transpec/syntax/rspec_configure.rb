# coding: utf-8

require 'transpec/syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      require 'transpec/syntax/rspec_configure/framework'

      def self.target_node?(node, runtime_data = nil)
        return false unless node && node.block_type?
        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node
        Util.const_name(receiver_node) == 'RSpec' && method_name == :configure
      end

      def self.add_framework(type, framework_block_method_name)
        class_eval <<-END
          def #{type}
            @#{type} ||= Framework.new(node, :#{framework_block_method_name}, source_rewriter)
          end
        END
      end

      add_framework :expectations, :expect_with
      add_framework :mocks,        :mock_with
    end
  end
end
