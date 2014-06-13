# coding: utf-8

require 'transpec/annotatable'

module Transpec
  class Record
    attr_reader :old_syntax_type, :new_syntax_type, :annotation

    def initialize(old_syntax, new_syntax, annotation = nil)
      # Keep these syntax data as symbols for:
      #   * Better memory footprint
      #   * Better summarizing performance in Report
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
  end

  # This class is intended to be inherited to build complex record.
  # The reasons why you should inherit this class rather than Record are:
  #   * You need to care about String and Symbol around Record#old_syntax and #new_syntax.
  #   * All record instances are kept in a Report until the end of Transpec process.
  #     This mean that if a custom record keeps a syntax object as an ivar,
  #     the AST kept by the syntax object won't be GCed.
  class RecordBuilder
    def self.build(*args)
      new(*args).build
    end

    def build
      Record.new(old_syntax, new_syntax, annotation)
    end

    private

    def initialize(*)
    end

    def old_syntax
      nil
    end

    def new_syntax
      nil
    end

    def annotation
      nil
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
