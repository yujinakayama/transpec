# coding: utf-8

require 'transpec/syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      require 'transpec/syntax/rspec_configure/framework'
      require 'transpec/syntax/rspec_configure/mocks'

      def self.target_node?(node, runtime_data = nil)
        return false unless node && node.block_type?
        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node
        Util.const_name(receiver_node) == 'RSpec' && method_name == :configure
      end

      def expectations
        @expectations ||= Framework.new(node, :expect_with, source_rewriter)
      end

      def mocks
        @mocks ||= Mocks.new(node, :mock_with, source_rewriter)
      end
    end
  end
end
