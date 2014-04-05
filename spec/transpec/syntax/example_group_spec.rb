# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/example_group'

module Transpec
  class Syntax
    describe ExampleGroup do
      include_context 'parsed objects'
      include_context 'syntax object', ExampleGroup, :example_group

      let(:record) { example_group.report.records.first }

      describe '#convert_to_non_monkey_patch!' do
        context 'when it is in top level scope' do
          [
            :describe,
            :shared_examples,
            :shared_context,
            :share_examples_for,
            :shared_examples_for
          ].each do |method|
            context "with expression `#{method} 'something' do ... end`" do
              let(:source) do
                <<-END
                  #{method} 'something' do
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  RSpec.#{method} 'something' do
                  end
                END
              end

              it "converts to `RSpec.#{method} 'something' do ... end`" do
                example_group.convert_to_non_monkey_patch!
                rewritten_source.should == expected_source
              end

              it "adds record `#{method} 'something' { }` -> `RSpec.#{method} 'something' { }`" do
                example_group.convert_to_non_monkey_patch!
                record.original_syntax.should  == "#{method} 'something' { }"
                record.converted_syntax.should == "RSpec.#{method} 'something' { }"
              end
            end
          end
        end

        context 'when the #describe is in a module' do
          let(:source) do
            <<-END
              module SomeModule
                describe 'something' do
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              module SomeModule
                RSpec.describe 'something' do
                end
              end
            END
          end

          it 'converts' do
            example_group.convert_to_non_monkey_patch!
            rewritten_source.should == expected_source
          end
        end

        shared_context 'multiple #describes' do
          before do
            ast.each_node do |node|
              example_group = described_class.new(node, source_rewriter, runtime_data)
              next unless example_group.conversion_target?
              example_group.convert_to_non_monkey_patch!
            end
          end
        end

        context 'when #describes are nested' do
          include_context 'multiple #describes'

          let(:source) do
            <<-END
              describe 'something' do
                describe '#some_method' do
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              RSpec.describe 'something' do
                describe '#some_method' do
                end
              end
            END
          end

          it 'converts only the outermost #describe' do
            rewritten_source.should == expected_source
          end
        end

        context 'when logical-inner #describe is placed outside of the outer #describe in source' do
          include_context 'multiple #describes'

          let(:source) do
            <<-END
              inner_proc = proc do
                describe 'inner' do
                end
              end

              describe 'outer' do
                instance_eval(&inner_proc)
              end
            END
          end

          context 'without runtime information' do
            let(:expected_source) do
              <<-END
              inner_proc = proc do
                RSpec.describe 'inner' do
                end
              end

              RSpec.describe 'outer' do
                instance_eval(&inner_proc)
              end
              END
            end

            it 'unfortunately converts both #describe' do
              rewritten_source.should == expected_source
            end
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            let(:expected_source) do
              <<-END
              inner_proc = proc do
                describe 'inner' do
                end
              end

              RSpec.describe 'outer' do
                instance_eval(&inner_proc)
              end
              END
            end

            it 'properly converts only the outermost #describe' do
              rewritten_source.should == expected_source
            end
          end
        end
      end
    end
  end
end
