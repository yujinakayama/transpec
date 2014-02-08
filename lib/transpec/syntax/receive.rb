# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/mixin/owned_matcher'
require 'transpec/syntax/mixin/any_instance_block'
require 'transpec/syntax/mixin/useless_and_return'

module Transpec
  class Syntax
    class Receive < Syntax
      include Mixin::Send, Mixin::OwnedMatcher, Mixin::AnyInstanceBlock, Mixin::UselessAndReturn

      attr_reader :expectation

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && method_name == :receive
      end

      def remove_useless_and_return!
        removed = super
        return unless removed
        @report.records << ReceiveUselessAndReturnRecord.new(self)
      end

      def add_receiver_arg_to_any_instance_implementation_block!
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

      class ReceiveUselessAndReturnRecord < UselessAndReturnRecord
        def base_syntax
          "#{@host.expectation.method_name_for_instance}(obj).to receive(:message)"
        end
      end
    end
  end
end
