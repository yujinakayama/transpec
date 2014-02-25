# coding: utf-8

module Transpec
  class ContextError < StandardError
    attr_reader :message, :source_range

    def initialize(source_range, original_syntax, target_syntax)
      @source_range = source_range
      @message = build_message(original_syntax, target_syntax)
    end

    def source_buffer
      source_range.source_buffer
    end

    private

    def build_message(original_syntax, target_syntax)
      "Cannot convert #{original_syntax} into #{target_syntax} " +
      "since #{target_syntax} is not available in the context."
    end
  end
end
