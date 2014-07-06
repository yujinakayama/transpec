# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/current_example'

module Transpec
  class Syntax
    describe CurrentExample do
      include_context 'parsed objects'
      include_context 'syntax object', CurrentExample, :current_example_object

      let(:record) { current_example_object.report.records.last }

      describe '#conversion_target?' do
        let(:target_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :example
          end
        end

        let(:current_example_object) do
          CurrentExample.new(target_node, source_rewriter, runtime_data)
        end

        subject { current_example_object.conversion_target? }

        context 'with #example node that returns current example object' do
          let(:source) do
            <<-END
              describe 'example' do
                after do
                  do_something if example.metadata[:foo]
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when #example node that defines a spec example is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                example 'it does something' do
                  do_something
                end
              end
            END
          end

          it { should be_false }
        end

        context 'when #example node defined with #let by user is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                let(:example) { 'This is not current example object' }

                it 'does something' do
                  example
                end
              end
            END
          end

          it 'unfortunately returns true ' \
             "since it's impossible to differentiate them without runtime information" do
            should be_true
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            it 'returns false properly' do
              should be_false
            end
          end
        end
      end

      describe '#convert!' do
        before do
          current_example_object.convert! unless example.metadata[:no_auto_convert]
        end

        (RSpecDSL::EXAMPLE_METHODS + RSpecDSL::HOOK_METHODS).each do |method|
          context "with expression `#{method} do example end`" do
            let(:source) do
              <<-END
                describe 'example' do
                  #{method} do
                    do_something if example.metadata[:foo]
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  #{method} do |example|
                    do_something if example.metadata[:foo]
                  end
                end
              END
            end

            it "converts to `#{method} do |example| example end` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{method} { example }` -> `#{method} { |example| example }`" do
              record.old_syntax.should == "#{method} { example }"
              record.new_syntax.should == "#{method} { |example| example }"
            end
          end
        end

        RSpecDSL::HELPER_METHODS.each do |method|
          context "with expression `#{method}(:name) do example end`" do
            let(:source) do
              <<-END
                describe 'example' do
                  #{method}(:name) do
                    do_something if example.metadata[:foo]
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  #{method}(:name) do |example|
                    do_something if example.metadata[:foo]
                  end
                end
              END
            end

            it "converts to `#{method}(:name) do |example| example end` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{method}(:name) { example }` -> `#{method}(:name) { |example| example }`" do
              record.old_syntax.should == "#{method}(:name) { example }"
              record.new_syntax.should == "#{method}(:name) { |example| example }"
            end
          end
        end

        context 'with expression `after { example }`' do
          let(:source) do
            <<-END
              describe 'example' do
                after {
                  do_something if example.metadata[:foo]
                }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                after { |example|
                  do_something if example.metadata[:foo]
                }
              end
            END
          end

          it 'converts to `after { |example| example }` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `after do running_example end`' do
          let(:source) do
            <<-END
              describe 'example' do
                after do
                  do_something if running_example.metadata[:foo]
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                after do |example|
                  do_something if example.metadata[:foo]
                end
              end
            END
          end

          it 'converts to `after do |example| example end` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when the wrapper block contains multiple invocation of `example`', :no_auto_convert do
          let(:source) do
            <<-END
              describe 'example' do
                after do
                  do_something if example.metadata[:foo]
                  puts example.description
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                after do |example|
                  do_something if example.metadata[:foo]
                  puts example.description
                end
              end
            END
          end

          let(:current_example_objects) do
            ast.each_node.each_with_object([]) do |node, objects|
              current_example_object = CurrentExample.new(node, source_rewriter, runtime_data)
              objects << current_example_object if current_example_object.conversion_target?
            end
          end

          it 'adds only a block argument' do
            current_example_objects.size.should eq(2)
            current_example_objects.each(&:convert!)
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `around do |ex| example end`' do
          let(:source) do
            <<-END
              describe 'example' do
                around do |ex|
                  do_something if example.metadata[:foo]
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                around do |ex|
                  do_something if ex.metadata[:foo]
                end
              end
            END
          end

          it 'converts to `around do |ex| ex end` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `def helper_method example; end`' do
          let(:source) do
            <<-END
              module Helper
                def display_description
                  puts example.description
                end
              end

              describe 'example' do
                include Helper

                after do
                  display_description
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              module Helper
                def display_description
                  puts RSpec.current_example.description
                end
              end

              describe 'example' do
                include Helper

                after do
                  display_description
                end
              end
            END
          end

          it 'converts to `def helper_method RSpec.current_example; end` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `def helper_method example; end` -> `def helper_method RSpec.current_example; end`' do
            record.old_syntax.should == 'def helper_method example; end'
            record.new_syntax.should == 'def helper_method RSpec.current_example; end'
          end
        end
      end
    end
  end
end
