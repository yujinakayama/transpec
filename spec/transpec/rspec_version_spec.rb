# coding: utf-8

require 'spec_helper'
require 'transpec/rspec_version'

module Transpec
  describe RSpecVersion do
    subject(:rspec_version) { RSpecVersion.new(version_string) }

    shared_examples 'version comparisons' do |method, expectations|
      describe "##{method}" do
        subject { rspec_version.send(method) }

        expectations.each do |version, expected|
          context "when the version is #{version}" do
            let(:version_string) { version }

            it "returns #{expected.inspect}" do
              should be expected
            end
          end
        end
      end
    end

    [
      :be_truthy_available?,
      :yielded_example_available?,
      :config_output_stream_available?,
      :yielding_receiver_to_any_instance_implementation_block_available?
    ].each do |method|
      include_examples 'version comparisons', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', true],
        ['2.99.0.beta2', true],
        ['2.99.0.rc1',   true],
        ['2.99.0',       true],
        ['3.0.0.beta1',  true],
        ['3.0.0.beta2',  true],
        ['3.0.0.rc1',    true],
        ['3.0.0',        true]
      ]
    end

    [
      :oneliner_is_expected_available?,
      :skip_available?
    ].each do |method|
      include_examples 'version comparisons', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0.beta2', true],
        ['2.99.0.rc1',   true],
        ['2.99.0',       true],
        ['3.0.0.beta1',  false],
        ['3.0.0.beta2',  true],
        ['3.0.0.rc1',    true],
        ['3.0.0',        true]
      ]
    end

    [
      :config_pattern_available?,
      :config_backtrace_formatter_available?,
      :config_predicate_color_enabled_available?,
      :config_predicate_warnings_available?,
      :implicit_spec_type_disablement_available?
    ].each do |method|
      include_examples 'version comparisons', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0.beta2', false],
        ['2.99.0.rc1',   true],
        ['2.99.0',       true],
        ['3.0.0.beta1',  false],
        ['3.0.0.beta2',  false],
        ['3.0.0.rc1',    true],
        ['3.0.0',        true]
      ]
    end

    [
      :receive_messages_available?
    ].each do |method|
      include_examples 'version comparisons', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0.beta2', false],
        ['2.99.0.rc1',   false],
        ['2.99.0',       false],
        ['3.0.0.beta1',  true],
        ['3.0.0.beta2',  true],
        ['3.0.0.rc1',    true],
        ['3.0.0',        true]
      ]
    end

    [
      :receive_message_chain_available?,
      :non_should_matcher_protocol_available?,
      :non_monkey_patch_example_group_available?,
      :hook_scope_alias_available?
    ].each do |method|
      include_examples 'version comparisons', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0.beta2', false],
        ['2.99.0.rc1',   false],
        ['2.99.0',       false],
        ['3.0.0.beta1',  false],
        ['3.0.0.beta2',  true],
        ['3.0.0.rc1',    true],
        ['3.0.0',        true]
      ]
    end

    include_examples 'version comparisons', :rspec_2_99?, [
      ['2.14.0',       false],
      ['2.99.0.beta1', true],
      ['2.99.0.beta2', true],
      ['2.99.0.rc1',   true],
      ['2.99.0',       true],
      ['3.0.0.beta1',  false],
      ['3.0.0.beta2',  false],
      ['3.0.0.rc1',    false],
      ['3.0.0',        false]
    ]
  end
end
