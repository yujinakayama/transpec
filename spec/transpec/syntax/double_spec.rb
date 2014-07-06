# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/double'

module Transpec
  class Syntax
    describe Double do
      include_context 'parsed objects'
      include_context 'syntax object', Double, :double_object

      describe '#conversion_target?' do
        let(:target_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :double
          end
        end

        let(:double_object) do
          Double.new(target_node, source_rewriter, runtime_data)
        end

        subject { double_object.conversion_target? }

        context 'when #double node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'includes something' do
                  something = double('something')
                  [1, something].should include(something)
                end
              end
            END
          end

          it { should be_true }
        end

        context 'with runtime information' do
          include_context 'dynamic analysis objects'

          context "when RSpec's #double node is passed" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'includes something' do
                    something = double('something')
                    [1, something].should include(something)
                  end
                end
              END
            end

            it { should be_true }
          end

          context 'when another #double node is passed' do
            let(:source) do
              <<-END
                module AnotherMockFramework
                  def setup_mocks_for_rspec
                    def double(arg)
                      arg.upcase
                    end
                  end

                  def verify_mocks_for_rspec
                  end

                  def teardown_mocks_for_rspec
                  end
                end

                RSpec.configure do |config|
                  config.mock_framework = AnotherMockFramework
                end

                describe 'example' do
                  it "is not RSpec's #double" do
                    something = double('something')
                    [1, something].should include('SOMETHING')
                  end
                end
              END
            end

            it { should be_false }
          end
        end
      end

      describe '#method_name' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'includes something' do
                something = double('something')
                [1, something].should include(something)
              end
            end
          END
        end

        it 'returns the method name' do
          double_object.method_name.should == :double
        end
      end

      describe '#convert_to_double!' do
        before do
          double_object.convert_to_double!
        end

        [:mock, :stub].each do |method|
          context "with expression `#{method}('something')`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'includes something' do
                    something = #{method}('something')
                    [1, something].should include(something)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'includes something' do
                    something = double('something')
                    [1, something].should include(something)
                  end
                end
              END
            end

            it "converts to `#{method}('something')`" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{method}('something')` -> `double('something')`" do
              record = double_object.report.records.first
              record.old_syntax.should == "#{method}('something')"
              record.new_syntax.should == "double('something')"
            end
          end
        end

        context "with expression `double('something')`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'includes something' do
                  something = double('something')
                  [1, something].should include(something)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            double_object.report.records.should be_empty
          end
        end
      end
    end
  end
end
