# coding: utf-8

require 'transpec/ast/node'

module Transpec
  module AST
    class Builder < Parser::Builders::Default
      def n(type, children, source_map)
        Node.new(type, children, location: source_map)
      end
    end
  end
end
