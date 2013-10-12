# coding: utf-8

require 'transpec/util'

module Transpec
  class Context
    include Util

    SCOPE_TYPES = [:module, :class, :sclass, :def, :defs, :block].freeze

    EXAMPLE_GROUP_METHODS = [
      :describe, :context,
      :shared_examples, :shared_context, :share_examples_for, :shared_examples_for
    ].freeze

    EXAMPLE_METHODS = [
      :example, :it, :specify,
      :focus, :focused, :fit,
      :pending, :xexample, :xit, :xspecify
    ].freeze

    HOOK_METHODS = [:before, :after, :around].freeze

    HELPER_METHODS = [:subject, :subject!, :let, :let!]

    EXAMPLE_GROUP_CONTEXT_SCOPE_SUFFIXES = [
      [:example_group, :example],
      [:example_group, :each_before_after],
      [:example_group, :all_before_after],
      [:example_group, :around],
      [:example_group, :helper],
      [:example_group, :def],
      [:rspec_configure, :each_before_after],
      [:rspec_configure, :all_before_after],
      [:rspec_configure, :around],
      [:rspec_configure, :def],
      [:module, :def]
    ].freeze

    NON_MONKEY_PATCH_MOCK_AVAILABLE_CONTEXT = [
      [:example_group, :example],
      [:example_group, :each_before_after],
      [:example_group, :helper],
      [:example_group, :def],
      [:rspec_configure, :each_before_after],
      [:rspec_configure, :def],
      [:module, :def]
    ].freeze

    attr_reader :nodes

    # @param nodes [Array] An array containing from root node to the target node.
    def initialize(nodes)
      @nodes = nodes
    end

    def scopes
      @scopes ||= begin
        scopes = @nodes.map { |node| scope_type(node) }
        scopes.compact!
        scopes.extend(ArrayExtension)
      end
    end

    def in_example_group?
      return @in_example_group if instance_variable_defined?(:@in_example_group)

      return @in_example_group = true if scopes == [:def]

      @in_example_group = EXAMPLE_GROUP_CONTEXT_SCOPE_SUFFIXES.any? do |suffix|
        scopes.end_with?(suffix)
      end
    end

    def non_monkey_patch_expectation_available?
      in_example_group?
    end

    alias_method :expect_to_matcher_available?, :non_monkey_patch_expectation_available?

    def non_monkey_patch_mock_available?
      return @mock_available if instance_variable_defined?(:@mock_available)

      return @mock_available = true if scopes == [:def]

      @mock_available = NON_MONKEY_PATCH_MOCK_AVAILABLE_CONTEXT.any? do |suffix|
        scopes.end_with?(suffix)
      end
    end

    alias_method :expect_to_receive_available?, :non_monkey_patch_mock_available?
    alias_method :allow_to_receive_available?, :non_monkey_patch_mock_available?

    private

    def scope_type(node)
      return nil unless SCOPE_TYPES.include?(node.type)

      if node.type == :block
        special_block_type(node)
      else
        node.type
      end
    end

    def special_block_type(block_node)
      send_node = block_node.children.first
      receiver_node, method_name, *_ = *send_node

      if const_name(receiver_node) == 'RSpec' && method_name == :configure
        :rspec_configure
      elsif HOOK_METHODS.include?(method_name)
        hook_type(send_node)
      elsif receiver_node
        nil
      elsif EXAMPLE_GROUP_METHODS.include?(method_name)
        :example_group
      elsif EXAMPLE_METHODS.include?(method_name)
        :example
      elsif HELPER_METHODS.include?(method_name)
        :helper
      else
        nil
      end
    end

    def hook_type(send_node)
      _, method_name, arg_node, *_ = *send_node

      return :around if method_name == :around

      if arg_node && [:sym, :str].include?(arg_node.type)
         hook_arg = arg_node.children.first.to_sym
         return :all_before_after if hook_arg == :all
      end

      :each_before_after
    end

    module ArrayExtension
      def end_with?(*args)
        tail = args.flatten
        self[-(tail.size)..-1] == tail
      end
    end
  end
end
