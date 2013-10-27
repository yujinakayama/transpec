# coding: utf-8

module Transpec
  class Configuration
    NEGATIVE_FORMS_OF_TO = ['not_to', 'to_not'].freeze

    PREDICATES = [
      [:convert_should,            true],
      [:convert_should_receive,    true],
      [:convert_stub,              true],
      [:convert_have_items,        true],
      [:convert_deprecated_method, true],
      [:parenthesize_matcher_arg,  true],
      [:forced,                    false],
      [:skip_dynamic_analysis,     false],
      [:generate_commit_message,   false]
    ].freeze

    PREDICATES.each do |predicate, _|
      attr_accessor predicate
      alias_method predicate.to_s + '?', predicate
    end

    attr_accessor :negative_form_of_to, :rspec_command

    def initialize
      PREDICATES.each do |predicate, default_value|
        instance_variable_set('@' + predicate.to_s, default_value)
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
