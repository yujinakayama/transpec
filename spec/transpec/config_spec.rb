# coding: utf-8

require 'spec_helper'
require 'transpec/config'

module Transpec
  describe Config do
    subject(:config) { Config.new }

    context 'by default' do
      [
        [:forced?,                                                false],
        [:skip_dynamic_analysis?,                                 false],
        [:negative_form_of_to,                                    'not_to'],
        [:boolean_matcher_type,                                   :conditional],
        [:form_of_be_falsey,                                      'be_falsey'],
        [:add_explicit_type_metadata_to_example_group?,           false],
        [:add_receiver_arg_to_any_instance_implementation_block?, true],
        [:parenthesize_matcher_arg?,                              true]
      ].each do |attribute, value|
        describe "##{attribute}" do
          subject { config.send(attribute) }

          it "is #{value.inspect}" do
            should == value
          end
        end
      end
    end

    describe '#convert?' do
      subject { config.convert?(syntax) }

      context 'by default' do
        {
                  should: true,
                oneliner: true,
          should_receive: true,
                    stub: true,
              have_items: true,
                     its: true,
                 pending: true,
              deprecated: true,
           example_group: false,
              hook_scope: false,
          stub_with_hash: false
        }.each do |syntax, expected|
          context "with #{syntax.inspect}" do
            let(:syntax) { syntax }
            it { should be expected }
          end
        end
      end
    end

    describe '#negative_form_of_to=' do
      ['not_to', 'to_not'] .each do |form|
        context "when #{form.inspect} is passed" do
          it "sets #{form.inspect}" do
            config.negative_form_of_to = form
            config.negative_form_of_to.should == form
          end
        end
      end

      context 'when a form other than "not_to" or "to_not" is passed' do
        it 'raises error' do
          lambda do
            config.negative_form_of_to = 'foo'
          end.should raise_error(ArgumentError)
        end
      end
    end

    describe '#boolean_matcher_type=' do
      [:conditional, :exact] .each do |type|
        context "when #{type.inspect} is passed" do
          it "sets #{type.inspect}" do
            config.boolean_matcher_type = type
            config.boolean_matcher_type.should == type
          end
        end
      end

      context 'when a type other than :conditional or :exact is passed' do
        it 'raises error' do
          lambda do
            config.boolean_matcher_type = :foo
          end.should raise_error(ArgumentError)
        end
      end
    end

    describe '#form_of_be_falsey=' do
      ['be_falsey', 'be_falsy'] .each do |form|
        context "when #{form.inspect} is passed" do
          it "sets #{form.inspect}" do
            config.form_of_be_falsey = form
            config.form_of_be_falsey.should == form
          end
        end
      end

      context 'when a form other than "be_falsey" or "be_falsy" is passed' do
        it 'raises error' do
          lambda do
            config.form_of_be_falsey = 'foo'
          end.should raise_error(ArgumentError)
        end
      end
    end
  end
end
