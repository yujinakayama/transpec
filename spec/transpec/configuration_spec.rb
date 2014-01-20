# coding: utf-8

require 'spec_helper'
require 'transpec/configuration'

module Transpec
  describe Configuration do
    subject(:configuration) { Configuration.new }

    context 'by default' do
      [
        [:convert_should?,                                        true],
        [:convert_oneliner?,                                      true],
        [:convert_should_receive?,                                true],
        [:convert_stub?,                                          true],
        [:convert_have_items?,                                    true],
        [:convert_its?,                                           true],
        [:convert_deprecated_method?,                             true],
        [:parenthesize_matcher_arg?,                              true],
        [:add_receiver_arg_to_any_instance_implementation_block?, true],
        [:forced?,                                                false],
        [:skip_dynamic_analysis?,                                 false],
        [:negative_form_of_to,                                    'not_to'],
        [:boolean_matcher_type,                                   :conditional],
        [:form_of_be_falsey,                                      'be_falsey']
      ].each do |attribute, value|
        describe "##{attribute}" do
          subject { configuration.send(attribute) }

          it "is #{value.inspect}" do
            should == value
          end
        end
      end
    end

    describe '#negative_form_of_to=' do
      ['not_to', 'to_not'] .each do |form|
        context "when #{form.inspect} is passed" do
          it "sets #{form.inspect}" do
            configuration.negative_form_of_to = form
            configuration.negative_form_of_to.should == form
          end
        end
      end

      context 'when a form other than "not_to" or "to_not" is passed' do
        it 'raises error' do
          lambda do
            configuration.negative_form_of_to = 'foo'
          end.should raise_error(ArgumentError)
        end
      end
    end

    describe '#boolean_matcher_type=' do
      [:conditional, :exact] .each do |type|
        context "when #{type.inspect} is passed" do
          it "sets #{type.inspect}" do
            configuration.boolean_matcher_type = type
            configuration.boolean_matcher_type.should == type
          end
        end
      end

      context 'when a type other than :conditional or :exact is passed' do
        it 'raises error' do
          lambda do
            configuration.boolean_matcher_type = :foo
          end.should raise_error(ArgumentError)
        end
      end
    end

    describe '#form_of_be_falsey=' do
      ['be_falsey', 'be_falsy'] .each do |form|
        context "when #{form.inspect} is passed" do
          it "sets #{form.inspect}" do
            configuration.form_of_be_falsey = form
            configuration.form_of_be_falsey.should == form
          end
        end
      end

      context 'when a form other than "be_falsey" or "be_falsy" is passed' do
        it 'raises error' do
          lambda do
            configuration.form_of_be_falsey = 'foo'
          end.should raise_error(ArgumentError)
        end
      end
    end
  end
end
