# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module MonkeyPatch
        def register_request_of_syntax_availability_inspection(rewriter, key, methods)
          code = "self.class.name.start_with?('RSpec::')"

          methods.each do |method|
            code << " && respond_to?(#{method.inspect})"
          end

          rewriter.register_request(@node, key, code, :context)
        end

        def check_syntax_availability(key)
          node_data = runtime_node_data(@node)

          if node_data
            node_data[key]
          else
            context.send(key)
          end
        end

        def subject_node
          receiver_node
        end

        def subject_range
          receiver_range
        end
      end
    end
  end
end
