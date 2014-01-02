# coding: utf-8

require 'parser'

module Transpec
  module AST
    class Node < Parser::AST::Node
      TYPES = %w(
        true false nil
        int float
        str dstr
        sym dsym
        xstr
        regexp regopt
        array splat
        hash pair kwsplat
        irange erange
        self
        lvar ivar cvar gvar
        nth_ref back_ref
        const cbase
        defined?
        lvasgn ivasgn cvasgn gvasgn
        casgn
        masgn mlhs
        op_asgn or_asgn and_asgn
        module class sclass
        def defs undef
        alias
        args
        arg optarg restarg blockarg shadowarg kwarg kwoptarg kwrestarg
        send
        super zsuper
        yield
        block block_pass
        and or not
        if
        case when
        while until while_post until_post for
        break next redo return
        begin
        rescue resbody ensure retry
        preexe postexe
        iflipflop eflipflop
        match_current_line match_with_lvasgn
      ).map(&:to_sym).freeze

      attr_reader :metadata

      def initialize(type, children = [], properties = {})
        @metadata = {}
        @mutable_attributes = {}

        # ::AST::Node#initialize freezes itself.
        super

        each_child_node do |child_node|
          child_node.parent_node = self
        end
      end

      TYPES.each do |node_type|
        method_name = "#{node_type.to_s.gsub(/\W/, '')}_type?"
        define_method(method_name) do
          type == node_type
        end
      end

      def parent_node
        @mutable_attributes[:parent_node]
      end

      def parent_node=(node)
        @mutable_attributes[:parent_node] = node
      end

      protected :parent_node=

      def each_ancestor_node(&block)
        return to_enum(__method__) unless block_given?

        if parent_node
          yield parent_node
          parent_node.each_ancestor_node(&block)
        end

        self
      end

      def ancestor_nodes
        each_ancestor_node.to_a
      end

      def each_child_node
        return to_enum(__method__) unless block_given?

        children.each do |child|
          next unless child.is_a?(self.class)
          yield child
        end

        self
      end

      def child_nodes
        each_child_node.to_a
      end

      def each_descendent_node(&block)
        return to_enum(__method__) unless block_given?

        each_child_node do |child_node|
          yield child_node
          child_node.each_descendent_node(&block)
        end
      end

      def descendent_nodes
        each_descendent_node.to_a
      end

      def each_node(&block)
        return to_enum(__method__) unless block_given?
        yield self
        each_descendent_node(&block)
      end
    end
  end
end
