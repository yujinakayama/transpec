# coding: utf-8

module Transpec
  class Record
    attr_reader :original_syntax, :converted_syntax

    def initialize(original_syntax, converted_syntax)
      @original_syntax = original_syntax
      @converted_syntax = converted_syntax
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
end
