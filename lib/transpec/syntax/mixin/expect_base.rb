# coding: utf-8

require 'active_support/concern'
require 'transpec/syntax/mixin/send'
require 'transpec/syntax/receive'
require 'transpec/util'

module Transpec
  class Syntax
    module Mixin
      module ExpectBase
        extend ActiveSupport::Concern
        include Send

        included do
          add_dynamic_analysis_request do |rewriter|
            if Receive.dynamic_analysis_target_node?(matcher_node)
              create_receive_matcher.register_request_for_dynamic_analysis(rewriter)
            end
          end

          alias_method :subject_node, :arg_node
          alias_method :to_node, :parent_node
        end

        def current_syntax_type
          :expect
        end

        def method_name_for_instance
          fail NotImplementedError
        end

        def positive?
          to_method_name = to_node.children[1]
          to_method_name == :to
        end

        def matcher_node
          to_arg_node = to_node.children[2]
          Util.each_forward_chained_node(to_arg_node, :include_origin)
            .select(&:send_type?).to_a.last
        end

        def block_node
          Util.block_node_taken_by_method(to_node)
        end

        def subject_range
          subject_node.loc.expression
        end

        def receive_matcher
          return @receive_matcher if instance_variable_defined?(:@receive_matcher)

          @receive_matcher ||= if Receive.conversion_target_node?(matcher_node, @runtime_data)
                                 create_receive_matcher
                               else
                                 nil
                               end
        end

        private

        def create_receive_matcher
          Receive.new(matcher_node, self, @source_rewriter, @runtime_data, @report)
        end
      end
    end
  end
end
