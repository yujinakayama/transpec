# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/be_boolean'

module Transpec
  class Syntax
    describe BeBoolean do
      include_context 'parsed objects'
      include_context 'syntax object', BeBoolean, :be_boolean_object

      let(:record) { be_boolean_object.report.records.last }

      describe '#convert_to_conditional_matcher!' do
        before do
          be_boolean_object.convert_to_conditional_matcher!(arg)
        end

        let(:arg) { 'be_falsey' }

        context 'with expression `be_true`' do
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

          it 'converts to `be_truthy`' do
            rewritten_source.should == expected_source
          end

          it 'adds record `be_true` -> `be_truthy`' do
            record.old_syntax.should == 'be_true'
            record.new_syntax.should == 'be_truthy'
          end
        end

        context 'with expression `be_false`' do
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

          it 'converts to `be_falsey`' do
            rewritten_source.should == expected_source
          end

          it 'adds record `be_false` -> `be_falsey`' do
            record.old_syntax.should == 'be_false'
            record.new_syntax.should == 'be_falsey'
          end

          context 'and "be_falsy" is passed' do
            let(:arg) { 'be_falsy' }

            let(:expected_source) do
              <<-END
              describe 'example' do
                it 'is falsey' do
                  nil.should be_falsy
                end
              end
              END
            end

            it 'converts to `be_falsy`' do
              rewritten_source.should == expected_source
            end

            it 'adds record `be_false` -> `be_falsy`' do
              record.old_syntax.should == 'be_false'
              record.new_syntax.should == 'be_falsy'
            end
          end
        end
      end

      describe '#convert_to_exact_matcher!' do
        before do
          be_boolean_object.convert_to_exact_matcher!
        end

        context 'with expression `be_true`' do
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

          it 'converts to `be true`' do
            rewritten_source.should == expected_source
          end

          it 'adds record `be_true` -> `be true`' do
            record.old_syntax.should == 'be_true'
            record.new_syntax.should == 'be true'
          end
        end

        context 'with expression `be_false`' do
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

          it 'converts to `be false`' do
            rewritten_source.should == expected_source
          end

          it 'adds record `be_false` -> `be false`' do
            record.old_syntax.should == 'be_false'
            record.new_syntax.should == 'be false'
          end
        end
      end
    end
  end
end
