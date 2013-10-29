# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/be_boolean'

module Transpec
  class Syntax
    describe BeBoolean do
      include_context 'parsed objects'

      subject(:be_boolean_object) do
        ast.each_node do |node|
          next unless BeBoolean.target_node?(node)
          return BeBoolean.new(node, source_rewriter)
        end
        fail 'No be_boolean node is found!'
      end

      let(:record) { be_boolean_object.report.records.last }

      describe '#convert_to_conditional_matcher!' do
        before do
          be_boolean_object.convert_to_conditional_matcher!
        end

        context 'when it is `be_true`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is truthy' do
                  1.should be_true
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is truthy' do
                  1.should be_truthy
                end
              end
            END
          end

          it 'converts into `be_truthy`' do
            rewritten_source.should == expected_source
          end

          it 'adds record "`be_true` -> `be_truthy`"' do
            record.original_syntax.should  == 'be_true'
            record.converted_syntax.should == 'be_truthy'
          end
        end

        context 'when it is `be_false`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is falsey' do
                  nil.should be_false
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is falsey' do
                  nil.should be_falsey
                end
              end
            END
          end

          it 'converts into `be_falsey`' do
            rewritten_source.should == expected_source
          end

          it 'adds record "`be_false` -> `be_falsey`"' do
            record.original_syntax.should  == 'be_false'
            record.converted_syntax.should == 'be_falsey'
          end
        end
      end

      describe '#convert_to_exact_matcher!' do
        before do
          be_boolean_object.convert_to_exact_matcher!
        end

        context 'when it is `be_true`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is true' do
                  true.should be_true
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is true' do
                  true.should be true
                end
              end
            END
          end

          it 'converts into `be true`' do
            rewritten_source.should == expected_source
          end

          it 'adds record "`be_true` -> `be true`"' do
            record.original_syntax.should  == 'be_true'
            record.converted_syntax.should == 'be true'
          end
        end

        context 'when it is `be_false`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is false' do
                  false.should be_false
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is false' do
                  false.should be false
                end
              end
            END
          end

          it 'converts into `be false`' do
            rewritten_source.should == expected_source
          end

          it 'adds record "`be_false` -> `be false`"' do
            record.original_syntax.should  == 'be_false'
            record.converted_syntax.should == 'be false'
          end
        end
      end
    end
  end
end
