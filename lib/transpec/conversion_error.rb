# coding: utf-8

require 'transpec/annotatable'

module Transpec
  class ConversionError < StandardError
    include Annotatable
  end

  class ContextError < ConversionError
    def initialize(original_syntax, target_syntax, source_range)
      message = build_message(original_syntax, target_syntax)
      super(message, source_range)
    end

    private

    def build_message(original_syntax, target_syntax)
      "Cannot convert #{original_syntax} into #{target_syntax} " +
      "since #{target_syntax} is not available in the context."
    end
  end
end
