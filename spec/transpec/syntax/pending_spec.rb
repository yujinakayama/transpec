# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/pending'

module Transpec
  class Syntax
    describe Pending do
      include_context 'parsed objects'
      include_context 'syntax object', Pending, :pending_object

      let(:record) { pending_object.report.records.last }

      describe '.conversion_target_node?' do
        subject { Pending.conversion_target_node?(pending_node, runtime_data) }

        let(:pending_node) do
          ast.each_descendent_node do |node|
            next unless node.send_type?
            method_name = node.children[1]
            return node if method_name == :pending
          end
          fail 'No #pending node is found!'
        end

        context 'when #pending specification node inside of an example is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  pending
                end
              end
            END
          end

          context 'without runtime information' do
            it { should be_true }
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_true }
          end
        end

        context 'when #pending example node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                pending 'will be skipped' do
                end
              end
            END
          end

          context 'without runtime information' do
            it { should be_false }
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_false }
          end
        end
      end

      describe '#convert_deprecated_syntax!' do
        before do
          pending_object.convert_deprecated_syntax!
        end

        context 'when it is `pending` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  pending
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  skip
                end
              end
            END
          end

          it 'converts into `skip` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `pending` -> `skip`' do
            record.original_syntax.should  == 'pending'
            record.converted_syntax.should == 'skip'
          end
        end

        context "when it is `pending 'some reason'` form" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  pending 'some reason'
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  skip 'some reason'
                end
              end
            END
          end

          it "converts into `skip 'some reason` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `pending` -> `skip`' do
            record.original_syntax.should  == 'pending'
            record.converted_syntax.should == 'skip'
          end
        end

        context 'when it is singleline `pending { do_something_fail }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending { do_something_fail }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                  do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `pending { do_something_fail }` -> `pending; do_something_fail`' do
            record.original_syntax.should  == 'pending { do_something_fail }'
            record.converted_syntax.should == 'pending; do_something_fail'
          end
        end

        context "when it is singleline `pending('some reason') { do_something_fail }` form" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending('some reason') { do_something_fail }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending('some reason')
                  do_something_fail
                end
              end
            END
          end

          it "converts into `pending('some reason'); do_something_fail` form" do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is multiline `pending { do_something_fail }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending do
                    do_something_first
                    do_something_fail
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                  do_something_first
                  do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end
        end

        context "when it is multiline `pending('some reason') { do_something_fail }` form" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending('some reason') do
                    do_something_first
                    do_something_fail
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending('some reason')
                  do_something_first
                  do_something_fail
                end
              end
            END
          end

          it "converts into `pending('some reason'); do_something_fail` form" do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is multiline `pending { do_something_fail }` form ' \
                'but the body is not indented' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending do
                  do_something_first
                  do_something_fail
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                  do_something_first
                  do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is multiline `pending { do_something_fail }` form ' \
                'but the body is outdented' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending do
                do_something_first
                do_something_fail
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                do_something_first
                do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is multiline `pending { do_something_fail }` form ' \
                'but anomalistically the beginning and the body of block are same line' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending do do_something_fail
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                  do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is multiline `pending { do_something_fail }` form ' \
                'but anomalistically the body and the end of block are same line' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending do
                    do_something_fail end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is expected to fail' do
                  pending
                  do_something_fail
                end
              end
            END
          end

          it 'converts into `pending; do_something_fail` form' do
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
