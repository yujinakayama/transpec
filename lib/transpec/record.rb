# coding: utf-8

require 'transpec/annotatable'

module Transpec
  class Record
    attr_reader :original_syntax, :converted_syntax, :annotation

    def initialize(original_syntax, converted_syntax, annotation = nil)
      @original_syntax = original_syntax
      @converted_syntax = converted_syntax
      @annotation = annotation
    end

    def ==(other)
      self.class == other.class &&
        original_syntax == other.original_syntax &&
        converted_syntax == other.converted_syntax
    end

    alias_method :eql?, :==

    def hash
      original_syntax.hash ^ converted_syntax.hash
    end

    def to_s
      "`#{original_syntax}` -> `#{converted_syntax}`"
    end
  end

  class Annotation
    include Annotatable
  end

  class AccuracyAnnotation < Annotation
    def initialize(source_range)
      message = "The `#{source_range.source}` has been converted " \
                'but it might possibly be incorrect ' \
                'due to a lack of runtime information. ' \
                "It's recommended to review the change carefully."
      super(message, source_range)
    end
  end
end
