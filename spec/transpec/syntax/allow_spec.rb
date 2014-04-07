# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/allow'

module Transpec
  class Syntax
    describe Allow do
      include_context 'parsed objects'
      include_context 'syntax object', Allow, :allow_object

      describe '#subject_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'is empty' do
                allow(subject).to be_empty
              end
            end
          END
        end

        it 'returns subject node' do
          method_name = allow_object.subject_node.children[1]
          method_name.should == :subject
        end
      end

      describe '#matcher_node' do
        context 'when the matcher is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  allow(subject).to receive(:foo) { }
                end
              end
            END
          end

          it 'returns send node of the matcher' do
            method_name = allow_object.matcher_node.children[1]
            method_name.should == :receive
          end
        end

        context 'when the matcher is not taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  allow(subject).to be_empty
                end
              end
            END
          end

          it 'returns send node of the matcher' do
            method_name = allow_object.matcher_node.children[1]
            method_name.should == :be_empty
          end
        end
      end

      describe '#receive_matcher' do
        subject { allow_object.receive_matcher }

        let(:source) do
          <<-END
            describe 'example' do
              it 'receives :foo' do
                allow(subject).to receive(:foo)
              end
            end
          END
        end

        it 'returns an instance of Receive' do
          should be_an(Receive)
        end
      end

      describe '#block_node' do
        subject { allow_object.block_node }

        context 'when the #to is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives :foo' do
                  allow(subject).to receive(:foo) do |arg|
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
                  allow(subject).to receive(:foo) { |arg|
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
