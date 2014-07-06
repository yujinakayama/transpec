# coding: utf-8

require 'spec_helper'
require 'transpec/spec_suite'
require 'transpec/dynamic_analyzer'

module Transpec
  describe SpecSuite do
    include FileHelper
    include_context 'isolated environment'

    subject(:spec_suite) { SpecSuite.new(base_paths, runtime_data) }
    let(:runtime_data) { nil }
    let(:base_paths) { [] }

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

    describe '#main_rspec_configure_node?' do
      before do
        create_file('spec/spec_helper.rb', <<-END)
          RSpec.configure do |config|
          end
        END

        create_file('spec/unit/spec_helper.rb', <<-END)
          require 'spec_helper'

          RSpec.configure do |config|
          end
        END

        create_file('spec/unit/unit_spec.rb', <<-END)
          require 'unit/spec_helper'
        END
      end

      context 'without runtime information' do
        it 'returns true for every node' do
          spec_suite.specs.each do |spec|
            spec.ast.each_node do |node|
              spec_suite.main_rspec_configure_node?(node).should be_true
            end
          end
        end
      end

      context 'with runtime information' do
        let(:runtime_data) { Transpec::DynamicAnalyzer.new(silent: true).analyze(base_paths) }

        let(:main_rspec_configure_node) do
          spec_suite.specs.each do |spec|
            next unless spec.path == 'spec/spec_helper.rb'
            spec.ast.each_node(:send) do |send_node|
              return send_node if send_node.children[1] == :configure
            end
          end
          fail 'Main RSpec.configure node not found!'
        end

        it 'returns true only for the main RSpec.configure node' do
          spec_suite.main_rspec_configure_node?(main_rspec_configure_node).should be_true

          spec_suite.specs.each do |spec|
            spec.ast.each_node do |node|
              next if node.equal?(main_rspec_configure_node)
              spec_suite.main_rspec_configure_node?(node).should be_false
            end
          end
        end
      end
    end
  end
end
