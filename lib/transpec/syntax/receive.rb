# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/any_instance_block'

module Transpec
  class Syntax
    class Receive < Syntax
      include Mixin::Send, Mixin::AnyInstanceBlock

      attr_reader :expectation

      def self.standalone?
        false
      end

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && method_name == :receive
      end

      def initialize(node, expectation, source_rewriter = nil, runtime_data = nil, report = nil)
        @node = node
        @expectation = expectation
        @source_rewriter = source_rewriter
        @runtime_data = runtime_data
        @report = report || Report.new
      end

      def add_instance_arg_to_any_instance_implementation_block!
        added = super
        return unless added
        @report.records << Record.new(
          "#{@expectation.method_name}(Klass).to receive(:message) { |arg| }",
          "#{@expectation.method_name}(Klass).to receive(:message) { |instance, arg| }"
        )
      end

      def any_instance?
        @expectation.any_instance?
      end

      def any_instance_block_node
        return unless any_instance?
        super || @expectation.block_node
      end
    end
  end
end
