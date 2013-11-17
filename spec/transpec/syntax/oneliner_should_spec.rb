# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/oneliner_should'

module Transpec
  class Syntax
    describe OnelinerShould do
      include_context 'parsed objects'
      include_context 'syntax object', OnelinerShould, :should_object

      let(:record) { should_object.report.records.first }

      describe '#matcher_node' do
        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'returns its parent node' do
            should_object.parent_node.children[1].should == :==
            should_object.matcher_node.should == should_object.parent_node
          end
        end

        context 'when it is taking non-operator matcher without argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be_empty }
              end
            END
          end

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :be_empty
            should_object.matcher_node.should == should_object.arg_node
          end
        end

        context 'when it is taking non-operator matcher with argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should eq(1) }
              end
            END
          end

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :eq
            should_object.matcher_node.should == should_object.arg_node
          end
        end
      end

      describe '#operator_matcher' do
        subject { should_object.operator_matcher }

        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'returns an instance of OperatorMatcher' do
            should be_an(OperatorMatcher)
          end
        end

        context 'when it is taking non-operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be_empty }
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end

      describe '#expectize!' do
        context 'when it has an operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'invokes OperatorMatcher#convert_operator!' do
            should_object.operator_matcher.should_receive(:convert_operator!)
            should_object.expectize!
          end
        end

        context 'when it is `it { should be true }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be true }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it { is_expected.to be true }
              end
            END
          end

          it 'converts into `it { is_expected.to be true }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record "`it { should ... }` -> `it { is_expected.to ... }`"' do
            should_object.expectize!
            record.original_syntax.should  == 'it { should ... }'
            record.converted_syntax.should == 'it { is_expected.to ... }'
          end
        end

        context 'when it is `it { should() == 1 }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should() == 1 }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it { is_expected.to eq(1) }
              end
            END
          end

          it 'converts into `it { is_expected.to eq(1) }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
