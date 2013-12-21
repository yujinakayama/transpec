# coding: utf-8

# Aliases by Capybara:
# https://github.com/jnicklas/capybara/blob/2.2.0/lib/capybara/rspec/features.rb

module Transpec
  module RSpecDSL
    EXAMPLE_GROUP_METHODS = [
      :describe, :context,
      :shared_examples, :shared_context, :share_examples_for, :shared_examples_for,
      :feature # Capybara
    ].freeze

    EXAMPLE_METHODS = [
      :example, :it, :specify,
      :focus, :focused, :fit,
      :pending, :xexample, :xit, :xspecify,
      :scenario, :xscenario # Capybara
    ].freeze

    HOOK_METHODS = [
      :before, :after, :around,
      :background # Capybara
    ].freeze

    HELPER_METHODS = [
      :subject, :subject!, :let, :let!,
      :given, :given! # Capybara
    ].freeze
  end
end
