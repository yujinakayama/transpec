# coding: utf-8

require 'transpec/syntax'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      require 'transpec/syntax/rspec_configure/configuration_modification'
      require 'transpec/syntax/rspec_configure/expectations'
      require 'transpec/syntax/rspec_configure/mocks'

      include ConfigurationModification

      def dynamic_analysis_target?
        return false unless node && node.block_type?
        send_node = node.children.first
        receiver_node, method_name, *_ = *send_node
        const_name(receiver_node) == 'RSpec' && method_name == :configure
      end

      def expose_dsl_globally=(boolean)
        set_configuration!(:expose_dsl_globally, boolean)
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

      private

      def find_block_node
        node
      end
    end
  end
end
