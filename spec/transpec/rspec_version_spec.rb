# coding: utf-8

require 'spec_helper'
require 'transpec/rspec_version'

module Transpec
  describe RSpecVersion do
    subject(:rspec_version) { RSpecVersion.new(version_string) }

    shared_examples 'feature availability' do |method, expectations|
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

    [:be_truthy_available?, :yielded_example_available?].each do |method|
      include_examples 'feature availability', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', true],
        ['2.99.0',       true],
        ['3.0.0.beta1',  true],
        ['3.0.0',        true]
      ]
    end

    [:receive_message_chain_available?, :one_liner_is_expected_available?].each do |method|
      include_examples 'feature availability', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0.beta2', true],
        ['2.99.0',       true],
        ['3.0.0.beta1',  true],
        ['3.0.0',        true]
      ]
    end

    [:receive_messages_available?].each do |method|
      include_examples 'feature availability', method, [
        ['2.14.0',       false],
        ['2.99.0.beta1', false],
        ['2.99.0',       false],
        ['3.0.0.beta1',  true],
        ['3.0.0',        true]
      ]
    end
  end
end
