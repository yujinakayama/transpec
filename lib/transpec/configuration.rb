# coding: utf-8

module Transpec
  class Configuration
    NEGATIVE_FORMS_OF_TO = ['not_to', 'to_not'].freeze

    PREDICATES = [
      :convert_to_expect_to_matcher,
      :convert_to_expect_to_receive,
      :convert_to_allow_to_receive,
      :convert_have_items,
      :replace_deprecated_method,
      :parenthesize_matcher_arg
    ].freeze

    PREDICATES.each do |predicate|
      attr_accessor predicate
      alias_method predicate.to_s + '?', predicate
    end

    attr_accessor :negative_form_of_to

    def initialize
      PREDICATES.each do |predicate|
        instance_variable_set('@' + predicate.to_s, true)
      end

      self.negative_form_of_to = 'not_to'
    end

    def negative_form_of_to=(form)
      unless NEGATIVE_FORMS_OF_TO.include?(form.to_s)
        message = 'Negative form of "to" must be either '
        message << NEGATIVE_FORMS_OF_TO.map(&:inspect).join(' or ')
        fail ArgumentError, message
      end

      @negative_form_of_to = form.to_s.freeze
    end
  end
end
