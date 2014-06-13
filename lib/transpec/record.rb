# coding: utf-8

require 'transpec/annotatable'

module Transpec
  class Record
    OVERRIDE_FORBIDDEN_METHODS = [
      :old_syntax,
      :old_syntax_type,
      :new_syntax,
      :new_syntax_type
    ]

    attr_reader :old_syntax_type, :new_syntax_type, :annotation

    def initialize(old_syntax, new_syntax, annotation = nil)
      @old_syntax_type = old_syntax.to_sym
      @new_syntax_type = new_syntax.to_sym
      @annotation = annotation
    end

    def old_syntax
      old_syntax_type.to_s
    end

    def new_syntax
      new_syntax_type.to_s
    end

    def old_syntax_type
      @old_syntax_type ||= build_old_syntax.to_sym
    end

    def new_syntax_type
      @new_syntax_type ||= build_new_syntax.to_sym
    end

    def ==(other)
      self.class == other.class &&
        old_syntax_type == other.old_syntax_type &&
        new_syntax_type == other.new_syntax_type
    end

    alias_method :eql?, :==

    def hash
      old_syntax_type.hash ^ new_syntax_type.hash
    end

    def to_s
      "`#{old_syntax_type}` -> `#{new_syntax_type}`"
    end

    private

    def build_old_syntax
      fail NotImplementedError
    end

    def build_new_syntax
      fail NotImplementedError
    end

    def self.method_added(method_name)
      return unless OVERRIDE_FORBIDDEN_METHODS.include?(method_name)
      fail "Do not override Record##{method_name}."
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
