# coding: utf-8

module Transpec
  module Util
    module_function

    def proc_literal?(node)
      return false unless node.type == :block

      send_node = node.children.first
      receiver_node, method_name, *_ = *send_node

      if receiver_node.nil? || const_name(receiver_node) == 'Kernel'
        [:lambda, :proc].include?(method_name)
      elsif const_name(receiver_node) == 'Proc'
        method_name == :new
      else
        false
      end
    end

    def const_name(node)
      return nil if node.nil? || node.type != :const

      const_names = []
      const_node = node

      loop do
        namespace_node, name = *const_node
        const_names << name
        break unless namespace_node
        break if namespace_node.type == :cbase
        const_node = namespace_node
      end

      const_names.reverse.join('::')
    end

    def here_document?(node)
      return false unless [:str, :dstr].include?(node.type)
      node.loc.begin.source.start_with?('<<')
    end

    def indentation_of_line(node)
      line = node.loc.expression.source_line
      /^(?<indentation>\s*)\S/ =~ line
      indentation
    end
  end
end
