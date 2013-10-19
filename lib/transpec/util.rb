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
        break unless namespace_node.is_a?(Parser::AST::Node)
        break if namespace_node.type == :cbase
        const_node = namespace_node
      end

      const_names.reverse.join('::')
    end

    def here_document?(node)
      return false unless [:str, :dstr].include?(node.type)
      map = node.loc
      return false if !map.respond_to?(:begin) || map.begin.nil?
      map.begin.source.start_with?('<<')
    end

    def contain_here_document?(node)
      here_document?(node) || node.each_descendent_node.any? { |n| here_document?(n) }
    end

    def in_parentheses?(node)
      return false unless node.type == :begin
      source = node.loc.expression.source
      source[0] == '(' && source[-1] == ')'
    end

    def indentation_of_line(arg)
      range = case arg
              when AST::Node             then arg.loc.expression
              when Parser::Source::Range then arg
              else fail ArgumentError, "Invalid argument #{arg}"
              end

      line = range.source_line
      /^(?<indentation>\s*)\S/ =~ line
      indentation
    end
  end
end
