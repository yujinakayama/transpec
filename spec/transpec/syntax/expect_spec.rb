# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/expect'

module Transpec
  class Syntax
    describe Expect do
      include_context 'parsed objects'
      include_context 'expect object'

      describe '#subject_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'is empty' do
                expect(subject).to be_empty
              end
            end
          END
        end

        it 'returns subject node' do
          method_name = expect_object.subject_node.children[1]
          method_name.should == :subject
        end
      end

      describe '#matcher_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'is empty' do
                expect(subject).to be_empty
              end
            end
          END
        end

        it 'returns matcher node' do
          method_name = expect_object.matcher_node.children[1]
          method_name.should == :be_empty
        end
      end

      describe '#have_matcher' do
        subject { expect_object.have_matcher }

        context 'when it is taking #have matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(subject).to have(2).items
                end
              end
            END
          end

          it 'returns an instance of Have' do
            should be_an(Have)
          end
        end

        context 'when it is taking any other matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  expect(subject).to be_empty
                end
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end
    end
  end
end
