# coding: utf-8

require 'transpec/syntax/rspec_configure/framework'

module Transpec
  class Syntax
    class RSpecConfigure
      class Mocks < Framework
        def framework_block_method_name
          :mock_with
        end

        def yield_receiver_to_any_instance_implementation_blocks=(boolean)
          set_configuration!(:yield_receiver_to_any_instance_implementation_blocks, boolean)
        end
      end
    end
  end
end
