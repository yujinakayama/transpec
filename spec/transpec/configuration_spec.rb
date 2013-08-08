# coding: utf-8

require 'spec_helper'

module Transpec
  describe Configuration do
    subject(:configuration) { Configuration.new }

    context 'by default' do
      [
        :convert_to_expect_to_matcher?,
        :convert_to_expect_to_receive?,
        :convert_to_allow_to_receive?,
        :replace_deprecated_method?,
        :parenthesize_matcher_arg?
      ].each do |attribute|
        describe "##{attribute}" do
          subject { configuration.send(attribute) }

          it 'is true' do
            should be_true
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
          proc do
            configuration.negative_form_of_to = 'foo'
          end.should raise_error(ArgumentError)
        end
      end
    end
  end
end
