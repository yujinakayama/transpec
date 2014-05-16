# coding: utf-8

module Transpec
  class Config
    NEGATIVE_FORMS_OF_TO = ['not_to', 'to_not'].freeze
    FORMS_OF_BE_FALSEY = ['be_falsey', 'be_falsy'].freeze
    BOOLEAN_MATCHER_TYPES = [:conditional, :exact].freeze

    PREDICATES = [
      [:forced,                                                false],
      [:convert_should,                                        true],
      [:convert_oneliner,                                      true],
      [:convert_should_receive,                                true],
      [:convert_stub,                                          true],
      [:convert_have_items,                                    true],
      [:convert_its,                                           true],
      [:convert_pending,                                       true],
      [:convert_deprecated_method,                             true],
      [:convert_example_group,                                 false],
      [:convert_hook_scope,                                    false],
      [:convert_stub_with_hash_to_allow_to_receive_and_return, false],
      [:skip_dynamic_analysis,                                 false],
      [:add_receiver_arg_to_any_instance_implementation_block, true],
      [:add_explicit_type_metadata_to_example_group,           true],
      [:parenthesize_matcher_arg,                              true]
    ].freeze

    PREDICATES.each do |predicate, _|
      attr_accessor predicate
      alias_method predicate.to_s + '?', predicate
    end

    attr_accessor :negative_form_of_to, :boolean_matcher_type, :form_of_be_falsey, :rspec_command

    def initialize
      PREDICATES.each do |predicate, default_value|
        instance_variable_set('@' + predicate.to_s, default_value)
      end

      self.negative_form_of_to = 'not_to'
      self.boolean_matcher_type = :conditional
      self.form_of_be_falsey = 'be_falsey'
    end

    def negative_form_of_to=(form)
      validate!(form.to_s, NEGATIVE_FORMS_OF_TO, 'Negative form of "to"')
      @negative_form_of_to = form.to_s.freeze
    end

    def boolean_matcher_type=(type)
      validate!(type.to_sym, BOOLEAN_MATCHER_TYPES, 'Boolean matcher type')
      @boolean_matcher_type = type.to_sym
    end

    def form_of_be_falsey=(form)
      validate!(form.to_s, FORMS_OF_BE_FALSEY, 'Form of "be_falsey"')
      @form_of_be_falsey = form.to_s.freeze
    end

    private

    def validate!(arg, valid_values, subject)
      return if valid_values.include?(arg)
      message = "#{subject} must be either "
      message << valid_values.map(&:inspect).join(' or ')
      fail ArgumentError, message
    end
  end
end
