# coding: utf-8

require 'transpec/syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      require 'transpec/syntax/rspec_configure/expectations'
      require 'transpec/syntax/rspec_configure/mocks'

      include Util

      def self.target_node?(node, runtime_data = nil)
        return false unless node && node.block_type?
        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node
        Util.const_name(receiver_node) == 'RSpec' && method_name == :configure
      end

      def expectations
        @expectations ||= Expectations.new(self, source_rewriter)
      end

      def mocks
        @mocks ||= Mocks.new(self, source_rewriter)
      end

      def block_arg_name
        first_block_arg_name(node)
      end
    end
  end
end
