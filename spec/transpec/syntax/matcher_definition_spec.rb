# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/matcher_definition'

module Transpec
  class Syntax
    describe MatcherDefinition do
      include_context 'parsed objects'
      include_context 'syntax object', MatcherDefinition, :matcher_definition

      let(:record) { matcher_definition.report.records.last }

      describe '#convert_deprecated_method!' do
        before do
          matcher_definition.convert_deprecated_method!
        end

        [
          [:match_for_should,               :match],
          [:match_for_should_not,           :match_when_negated],
          [:failure_message_for_should,     :failure_message],
          [:failure_message_for_should_not, :failure_message_when_negated]
        ].each do |target_method, converted_method|
          context "with expression `#{target_method} { }`" do
            let(:source) do
              <<-END
                RSpec::Matchers.define :be_awesome do |expected|
                  #{target_method} do |actual|
                    true
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                RSpec::Matchers.define :be_awesome do |expected|
                  #{converted_method} do |actual|
                    true
                  end
                end
              END
            end

            it "converts to `#{converted_method} { }` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{target_method} { }` -> `#{converted_method} { }`" do
              record.old_syntax.should == "#{target_method} { }"
              record.new_syntax.should == "#{converted_method} { }"
            end
          end
        end
      end
    end
  end
end
