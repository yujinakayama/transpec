# coding: utf-8

require 'transpec/util'

module Transpec
  class Context
    include Util

    SCOPE_TYPES = [:module, :class, :sclass, :def, :defs, :block].freeze

    EXAMPLE_GROUP_METHOD_NAMES = [
      :describe, :context,
      :shared_examples, :shared_context, :share_examples_for, :shared_examples_for
    ].freeze

    attr_reader :nodes

    # @param nodes [Array] An array containing from root node to the target node.
    def initialize(nodes)
      @nodes = nodes
    end

    def scopes
      @scopes ||= begin
        scopes = @nodes.map { |node| scope_type(node) }
        scopes.compact
      end
    end

    def in_example_group?
      return @in_example_group if instance_variable_defined?(:@in_example_group)
      @in_example_group = in_method_or_block_in_example_group?   ||
                          in_method_or_block_in_rspec_configure? ||
                          in_method_in_module?                   ||
                          in_method_in_top_level?
    end

    private

    def scope_type(node)
      return nil unless SCOPE_TYPES.include?(node.type)
      return node.type unless node.type == :block

      send_node = node.children.first
      receiver_node, method_name, *_ = *send_node

      if const_name(receiver_node) == 'RSpec' && method_name == :configure
        :rspec_configure
      elsif receiver_node
        node.type
      elsif EXAMPLE_GROUP_METHOD_NAMES.include?(method_name)
        :example_group
      else
        node.type
      end
    end

    def in_method_or_block_in_example_group?
      scopes_in_example_group = inner_scopes_of(:example_group)
      return false unless scopes_in_example_group
      return false if include_class_scope?(scopes_in_example_group)
      include_method_or_block_scope?(scopes_in_example_group)
    end

    def in_method_or_block_in_rspec_configure?
      scopes_in_rspec_configure = inner_scopes_of(:rspec_configure)
      return false unless scopes_in_rspec_configure
      return false if include_class_scope?(scopes_in_rspec_configure)
      include_method_or_block_scope?(scopes_in_rspec_configure)
    end

    def in_method_in_module?
      scopes_in_module = inner_scopes_of(:module)
      return false unless scopes_in_module
      return false if include_class_scope?(scopes_in_module)
      scopes_in_module.include?(:def)
    end

    def in_method_in_top_level?
      return false unless scopes.first == :def
      scopes_in_method = scopes[1..-1]
      !include_class_scope?(scopes_in_method)
    end

    def inner_scopes_of(scope_type)
      index = scopes.rindex(scope_type)
      return nil unless index
      scopes[Range.new(index + 1, -1)]
    end

    def include_class_scope?(scopes)
      !(scopes & [:class, :sclass]).empty?
    end

    def include_method_or_block_scope?(scopes)
      # TODO: Should validate whether the method taking the block is RSpec's
      #   special method. (e.g. #subject, #let, #before, #after)
      !(scopes & [:def, :block]).empty?
    end
  end
end
