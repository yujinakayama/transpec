# coding: utf-8

module Transpec
  module RSpecDSL
    EXAMPLE_GROUP_METHODS = [
      :describe, :context,
      :shared_examples, :shared_context, :share_examples_for, :shared_examples_for
    ].freeze

    EXAMPLE_METHODS = [
      :example, :it, :specify,
      :focus, :focused, :fit,
      :pending, :xexample, :xit, :xspecify
    ].freeze

    HOOK_METHODS = [:before, :after, :around].freeze

    HELPER_METHODS = [:subject, :subject!, :let, :let!].freeze
  end
end
