# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    module Mixin
      module Metadata
        extend ActiveSupport::Concern
        include Send

        def metadata_nodes
          arg_nodes[1..-1] || []
        end

        def metadata_key_nodes
          metadata_nodes.each_with_object([]) do |node, key_nodes|
            if node.hash_type?
              key_nodes.concat(node.children.map { |pair_node| pair_node.children.first })
            else
              key_nodes << node
            end
          end
        end
      end
    end
  end
end
