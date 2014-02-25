# coding: utf-8

module Transpec
  class ConversionError < StandardError
    attr_reader :message, :source_range

    def initialize(message, source_range)
      @message = message
      @source_range = source_range
    end

    def source_buffer
      source_range.source_buffer
    end
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
