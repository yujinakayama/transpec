# coding: utf-8

require 'spec_helper'
require 'transpec/configuration'

module Transpec
  describe Configuration do
    subject(:configuration) { Configuration.new }

    context 'by default' do
      [
        [:convert_should?,            true],
        [:convert_should_receive?,    true],
        [:convert_stub?,              true],
        [:convert_have_items?,        true],
        [:convert_deprecated_method?, true],
        [:parenthesize_matcher_arg?,  true],
        [:forced?,                    false],
        [:skip_dynamic_analysis?,     false],
        [:generate_commit_message?,   false]
      ].each do |attribute, value|
        describe "##{attribute}" do
          subject { configuration.send(attribute) }

          it "is #{value}" do
            should == value
          end
        end
      end

      describe '#negative_form_of_to' do
        it 'is "not_to"' do
          configuration.negative_form_of_to.should == 'not_to'
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
  end
end
