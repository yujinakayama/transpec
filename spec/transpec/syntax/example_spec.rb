# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/example'

module Transpec
  class Syntax
    describe Example do
      include_context 'parsed objects'
      include_context 'syntax object', Example, :example_object

      let(:record) { example_object.report.records.last }

      describe '#convert!' do
        before do
          example_object.convert! unless example.metadata[:no_auto_convert]
        end

        (RSpecDSL::EXAMPLE_METHODS + RSpecDSL::HOOK_METHODS).each do |method|
          context "when it is `#{method} do example end` form" do
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

            it "converts into `#{method} do |example| example end` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{method} { example }` -> `#{method} { |example| example }`" do
              record.original_syntax.should  == "#{method} { example }"
              record.converted_syntax.should == "#{method} { |example| example }"
            end
          end
        end

        RSpecDSL::HELPER_METHODS.each do |method|
          context "when it is `#{method}(:name) do example end` form" do
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

            it "converts into `#{method}(:name) do |example| example end` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{method}(:name) { example }` -> `#{method}(:name) { |example| example }`" do
              record.original_syntax.should  == "#{method}(:name) { example }"
              record.converted_syntax.should == "#{method}(:name) { |example| example }"
            end
          end
        end

        context 'when it is `after { example }` form' do
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

          it 'converts into `after { |example| example }` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `after do running_example end` form' do
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

          it 'converts into `after do |example| example end` form' do
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

          let(:example_objects) do
            ast.each_node.reduce([]) do |objects, node|
              objects << Example.new(node, source_rewriter, runtime_data) if Example.target_node?(node)
              objects
            end
          end

          it 'adds only a block argument' do
            example_objects.size.should eq(2)
            example_objects.each(&:convert!)
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `around do |ex| example end` form' do
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

          it 'converts into `around do |ex| ex end` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `def helper_method example; end` form' do
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

          it 'converts into `def helper_method RSpec.current_example; end` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `def helper_method example; end` -> `def helper_method RSpec.current_example; end`' do
            record.original_syntax.should  == 'def helper_method example; end'
            record.converted_syntax.should == 'def helper_method RSpec.current_example; end'
          end
        end
      end
    end
  end
end
