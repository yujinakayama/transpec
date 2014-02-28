# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/pending'

module Transpec
  class Syntax
    describe Pending do
      include_context 'parsed objects'
      include_context 'syntax object', Pending, :pending_object

      let(:record) { pending_object.report.records.last }

      # describe '.conversion_target_node?' do
      #   let(:send_node) do
      #     ast.each_descendent_node do |node|
      #       next unless node.send_type?
      #       method_name = node.children[1]
      #       next unless method_name == :double
      #       return node
      #     end
      #     fail 'No #double node is found!'
      #   end

      #   context 'when #double node is passed' do
      #     let(:source) do
      #       <<-END
      #         describe 'example' do
      #           it 'includes something' do
      #             something = double('something')
      #             [1, something].should include(something)
      #           end
      #         end
      #       END
      #     end

      #     it 'returns true' do
      #       Double.conversion_target_node?(send_node).should be_true
      #     end
      #   end

      #   context 'with runtime information' do
      #     include_context 'dynamic analysis objects'

      #     context "when RSpec's #double node is passed" do
      #       let(:source) do
      #         <<-END
      #           describe 'example' do
      #             it 'includes something' do
      #               something = double('something')
      #               [1, something].should include(something)
      #             end
      #           end
      #         END
      #       end

      #       it 'returns true' do
      #         Double.conversion_target_node?(send_node).should be_true
      #       end
      #     end

      #     context 'when another #double node is passed' do
      #       let(:source) do
      #         <<-END
      #           module AnotherMockFramework
      #             def setup_mocks_for_rspec
      #               def double(arg)
      #                 arg.upcase
      #               end
      #             end

      #             def verify_mocks_for_rspec
      #             end

      #             def teardown_mocks_for_rspec
      #             end
      #           end

      #           RSpec.configure do |config|
      #             config.mock_framework = AnotherMockFramework
      #           end

      #           describe 'example' do
      #             it "is not RSpec's #double" do
      #               something = double('something')
      #               [1, something].should include('SOMETHING')
      #             end
      #           end
      #         END
      #       end

      #       it 'returns false' do
      #         Double.conversion_target_node?(send_node, runtime_data).should be_false
      #       end
      #     end
      #   end
      # end

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
