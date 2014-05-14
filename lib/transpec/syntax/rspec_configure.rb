# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/rspec_rails'
require 'transpec/syntax/mixin/send'
require 'transpec/util'

module Transpec
  class Syntax
    class RSpecConfigure < Syntax
      require 'transpec/syntax/rspec_configure/config_modification'
      require 'transpec/syntax/rspec_configure/expectations'
      require 'transpec/syntax/rspec_configure/mocks'

      include Mixin::Send, Mixin::RSpecRails, ConfigModification

      define_dynamic_analysis do |rewriter|
        code = "TranspecAnalysis.global_data[:rspec_configure_run_order] ||= 0\n" \
               'TranspecAnalysis.global_data[:rspec_configure_run_order] += 1'
        rewriter.register_request(node, :run_order, code)
      end

      def dynamic_analysis_target?
        return false unless super
        const_name(receiver_node) == 'RSpec' && method_name == :configure && parent_node.block_type?
      end

      def expose_dsl_globally=(boolean)
        set_config!(:expose_dsl_globally, boolean)
      end

      def infer_spec_type_from_file_location!
        return if infer_spec_type_from_file_location?
        return unless rspec_rails?
        add_config!(:infer_spec_type_from_file_location!)
      end

      def infer_spec_type_from_file_location?
        !find_config_node(:infer_spec_type_from_file_location!).nil?
      end

      def expectations
        @expectations ||= Expectations.new(self, source_rewriter)
      end

      def mocks
        @mocks ||= Mocks.new(self, source_rewriter)
      end

      alias_method :block_node, :parent_node

      def block_arg_name
        first_block_arg_name(block_node)
      end
    end
  end
end
