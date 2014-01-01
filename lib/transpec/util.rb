# coding: utf-8

module Transpec
  module Util
    LITERAL_TYPES = %w(
      true false nil
      int float
      str sym regexp
    ).map(&:to_sym).freeze

    WHITESPACES = [' ', "\t"].freeze

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
      node.loc.respond_to?(:heredoc_end)
    end

    def contain_here_document?(node)
      node.each_node.any? { |n| here_document?(n) }
    end

    def in_explicit_parentheses?(node)
      return false unless node.type == :begin
      source = node.loc.expression.source
      source[0] == '(' && source[-1] == ')'
    end

    def taking_block?(node)
      parent_node = node.parent_node
      parent_node && parent_node.type == :block && parent_node.children.first.equal?(node)
    end

    def indentation_of_line(arg)
      line = case arg
             when AST::Node             then arg.loc.expression.source_line
             when Parser::Source::Range then arg.source_line
             when String                then arg
             else fail ArgumentError, "Invalid argument #{arg}"
             end

      /^(?<indentation>\s*)\S/ =~ line
      indentation
    end

    def literal?(node)
      case node.type
      when *LITERAL_TYPES
        true
      when :array, :irange, :erange
        node.children.all? { |n| literal?(n) }
      when :hash
        node.children.all? do |pair_node|
          pair_node.children.all? { |n| literal?(n) }
        end
      else
        false
      end
    end

    def expand_range_to_adjacent_whitespaces(range, direction = :both)
      source = range.source_buffer.source
      begin_pos = if [:both, :begin].include?(direction)
                    find_consecutive_whitespace_position(source, range.begin_pos, :downto)
                  else
                    range.begin_pos
                  end

      end_pos = if [:both, :end].include?(direction)
                  find_consecutive_whitespace_position(source, range.end_pos - 1, :upto) + 1
                else
                  range.end_pos
                end

      Parser::Source::Range.new(range.source_buffer, begin_pos, end_pos)
    end

    def find_consecutive_whitespace_position(source, origin, method)
      from, to = case method
                 when :upto
                   [origin + 1, source.length - 1]
                 when :downto
                   [origin - 1, 0]
                 else
                   fail "Invalid method #{method}"
                 end

      from.send(method, to).reduce(origin) do |previous_position, position|
        character = source[position]
        if WHITESPACES.include?(character)
          position
        else
          return previous_position
        end
      end
    end
  end
end
