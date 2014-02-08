# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/expect'

module Transpec
  class Syntax
    describe Expect do
      include_context 'parsed objects'
      include_context 'syntax object', Expect, :expect_object

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
        let(:matcher_name) { expect_object.matcher_node.children[1] }

        context 'when the matcher is not taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  expect(subject).to be_empty
                end
              end
            END
          end

          it 'returns send node of the matcher' do
            matcher_name.should == :be_empty
          end
        end

        context 'when the matcher is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo' do
                  expect(subject).to receive(:foo) { }
                end
              end
            END
          end

          it 'returns send node of the matcher' do
            matcher_name.should == :receive
          end
        end

        context 'when the matcher is chained by another method' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo twice' do
                  expect(subject).to receive(:foo).twice
                end
              end
            END
          end

          it 'returns the first node of the chain' do
            matcher_name.should == :receive
          end
        end

        context 'when the matcher is chained by another method that is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo twice' do
                  expect(subject).to receive(:foo).twice { }
                end
              end
            END
          end

          it 'returns the first node of the chain' do
            matcher_name.should == :receive
          end
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

      describe '#receive_matcher' do
        subject { expect_object.receive_matcher }

        context 'when it is taking #receive matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo' do
                  expect(subject).to receive(:foo)
                end
              end
            END
          end

          it 'returns an instance of Receive' do
            should be_an(Receive)
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

      describe '#block_node' do
        subject { expect_object.block_node }

        context 'when the #to is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo' do
                  expect(subject).to receive(:foo) do |arg|
                  end
                end
              end
            END
          end

          it 'returns the block node' do
            should be_block_type
          end
        end

        context 'when the #to is not taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo' do
                  expect(subject).to receive(:foo) { |arg|
                  }
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
