# coding: utf-8

require 'spec_helper'
require 'transpec/spec_suite'

module Transpec
  describe SpecSuite do
    include FileHelper
    include_context 'isolated environment'

    subject(:spec_suite) { SpecSuite.new }

    describe '#need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config?' do
      subject do
        spec_suite.need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config?
      end

      context "when there's an any_instance block to convert" do
        before do
          create_file('spec/example_spec.rb', <<-END)
            describe 'example' do
              it 'responds to #message' do
                Object.any_instance.stub(:message) do |arg|
                end
              end
            end
          END
        end

        it { should be_true }
      end

      context "when there's no any_instance block to convert" do
        before do
          create_file('spec/example_spec.rb', <<-END)
            describe 'example' do
              it 'responds to #message' do
                Object.any_instance.stub(:message) do
                end
              end
            end
          END
        end

        it { should be_false }
      end
    end
  end
end
