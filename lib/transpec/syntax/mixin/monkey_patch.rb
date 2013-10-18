# coding: utf-8

module Transpec
  class Syntax
    module Mixin
      module MonkeyPatch
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
