# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/expect'

module Transpec
  class Syntax
    describe Expect do
      include_context 'parsed objects'
      include_context 'syntax object', Expect, :expect_object

      describe '#conversion_target?' do
        let(:target_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :expect
          end
        end

        let(:expect_object) do
          Expect.new(target_node)
        end

        subject { expect_object.conversion_target? }

        context 'when the #expect node is chained by #to' do
          context 'and taking a matcher properly' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'is valid expectation' do
                    expect(obj).to matcher
                  end
                end
              END
            end

            it { should be_true }
          end

          context 'but taking no matcher' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'is invalid expectation' do
                    expect(obj).to
                  end
                end
              END
            end

            it { should be_false }
          end
        end

        context 'when the #expect node is chained by #not_to' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is valid expectation' do
                  expect(obj).not_to matcher
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when the #expect node is not chained' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is invalid expectation' do
                  expect(obj)
                end
              end
            END
          end

          it { should be_false }
        end

        context 'when the #expect node is not chained and taken as a argument by another method' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is invalid expectation' do
                  do_something(expect(obj))
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#subject_node' do
        context 'when the subject is a normal argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  expect(subject).to be_empty
                end
              end
            END
          end

          it 'returns the subject node' do
            method_name = expect_object.subject_node.children[1]
            method_name.should == :subject
          end
        end

        context 'when the subject is a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  expect { do_something }.to raise_error
                end
              end
            END
          end

          it 'returns the block node' do
            expect_object.subject_node.should be_block_type
          end
        end
      end

      describe '#to_node' do
        context 'when the subject is a normal argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  expect(subject).to be_empty
                end
              end
            END
          end

          it 'returns #to node' do
            method_name = expect_object.to_node.children[1]
            method_name.should == :to
          end
        end

        context 'when the subject is a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  expect { do_something }.to raise_error
                end
              end
            END
          end

          it 'returns #to node' do
            method_name = expect_object.to_node.children[1]
            method_name.should == :to
          end
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

      describe '#receive_matcher' do
        subject { expect_object.receive_matcher }

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
