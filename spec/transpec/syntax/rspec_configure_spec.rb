# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/rspec_configure'

module Transpec
  class Syntax
    describe RSpecConfigure do
      include_context 'parsed objects'
      include_context 'syntax object', RSpecConfigure, :rspec_configure

      context 'when multiple configurations are added' do
        before do
          rspec_configure.expose_dsl_globally = true
          rspec_configure.infer_spec_type_from_file_location!
        end

        let(:source) do
          <<-END
            RSpec.configure do |config|
            end
          END
        end

        let(:expected_source) do
          <<-END
            RSpec.configure do |config|
              config.expose_dsl_globally = true

              config.infer_spec_type_from_file_location!
            end
          END
        end

        it 'properly adds them' do
          rewritten_source.should == expected_source
        end
      end

      describe '#expose_dsl_globally=' do
        before do
          rspec_configure.expose_dsl_globally = value
        end

        let(:value) { true }

        let(:source) do
          <<-END
            RSpec.configure do |config|
              config.expose_dsl_globally = false
            end
          END
        end

        let(:expected_source) do
          <<-END
            RSpec.configure do |config|
              config.expose_dsl_globally = true
            end
          END
        end

        it 'rewrites the `expose_dsl_globally` configuration' do
          rewritten_source.should == expected_source
        end

        context 'when #expose_dsl_globally= does not exist' do
          let(:source) do
            <<-END
              RSpec.configure do |config|
              end
            END
          end

          let(:expected_source) do
            <<-END
              RSpec.configure do |config|
                config.expose_dsl_globally = true
              end
            END
          end

          it 'adds #expose_dsl_globally= statement' do
            rewritten_source.should == expected_source
          end
        end

        context 'when there are already some configurations' do
          let(:source) do
            <<-END
              RSpec.configure do |config|
                config.foo = 1
              end
            END
          end

          let(:expected_source) do
            <<-END
              RSpec.configure do |config|
                config.foo = 1

                config.expose_dsl_globally = true
              end
            END
          end

          it 'adds the block after a blank line' do
            rewritten_source.should == expected_source
          end
        end
      end

      describe '#infer_spec_type_from_file_location!' do
        before do
          rspec_configure.infer_spec_type_from_file_location!
        end

        context 'when #infer_spec_type_from_file_location! does not exist' do
          let(:source) do
            <<-END
              RSpec.configure do |config|
              end
            END
          end

          let(:expected_source) do
            <<-END
              RSpec.configure do |config|
                config.infer_spec_type_from_file_location!
              end
            END
          end

          it 'adds #infer_spec_type_from_file_location! statement' do
            rewritten_source.should == expected_source
          end
        end

        context 'when #infer_spec_type_from_file_location! already exists' do
          let(:source) do
            <<-END
              RSpec.configure do |config|
                config.infer_spec_type_from_file_location!
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'with runtime information' do
          include_context 'dynamic analysis objects'

          context 'when rspec-rails is loaded in the spec' do
            let(:source) do
              <<-END
                module RSpec
                  module Rails
                  end
                end

                RSpec.configure do |config|
                end
              END
            end

            let(:expected_source) do
              <<-END
                module RSpec
                  module Rails
                  end
                end

                RSpec.configure do |config|
                  config.infer_spec_type_from_file_location!
                end
              END
            end

            it 'adds #infer_spec_type_from_file_location! statement' do
              rewritten_source.should == expected_source
            end
          end

          context 'when rspec-rails is not loaded in the spec' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end
        end
      end

      shared_examples '#syntaxes' do |framework_block_method|
        describe '#syntaxes' do
          subject { super().syntaxes }

          context 'when :should is enabled' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                    c.syntax = :should
                  end
                end
              END
            end

            it 'returns [:should]' do
              should == [:should]
            end
          end

          context 'when :should and :expect are enabled' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                    c.syntax = [:should, :expect]
                  end
                end
              END
            end

            it 'returns [:should, :expect]' do
              should == [:should, :expect]
            end
          end

          context 'when the syntax is specified indirectly with method or variable' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                    c.syntax = some_syntax
                  end
                end
              END
            end

            it 'raises error' do
              -> { subject }.should raise_error(RSpecConfigure::Framework::UnknownSyntaxError)
            end
          end

          context "when ##{framework_block_method} block does not exist" do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                end
              END
            end

            it 'returns empty array' do
              should == []
            end
          end

          context "when ##{framework_block_method} { #syntax= } does not exist" do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                  end
                end
              END
            end

            it 'returns empty array' do
              should == []
            end
          end
        end
      end

      shared_examples '#syntaxes=' do |framework_block_method, block_arg_name|
        describe '#syntaxes=' do
          before do
            subject.syntaxes = syntaxes
          end

          let(:source) do
            <<-END
              RSpec.configure do |config|
                config.#{framework_block_method} :rspec do |c|
                  c.syntax = :should
                end
              end
            END
          end

          context 'when :expect is passed' do
            let(:syntaxes) { :expect }

            let(:expected_source) do
              <<-END
              RSpec.configure do |config|
                config.#{framework_block_method} :rspec do |c|
                  c.syntax = :expect
                end
              end
              END
            end

            it 'rewrites syntax specification to `c.syntax = :expect`' do
              rewritten_source.should == expected_source
            end
          end

          context 'when [:should, :expect] is passed' do
            let(:syntaxes) { [:should, :expect] }

            let(:expected_source) do
              <<-END
              RSpec.configure do |config|
                config.#{framework_block_method} :rspec do |c|
                  c.syntax = [:should, :expect]
                end
              end
              END
            end

            it 'rewrites syntax specification to `c.syntax = [:should, :expect]`' do
              rewritten_source.should == expected_source
            end
          end

          context "when ##{framework_block_method} { #syntax= } does not exist" do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                  end
                end
              END
            end

            let(:syntaxes) { :expect }

            let(:expected_source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |c|
                    c.syntax = :expect
                  end
                end
              END
            end

            it 'adds #syntax= statement' do
              rewritten_source.should == expected_source
            end
          end

          context "when ##{framework_block_method} block does not exist" do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                end
              END
            end

            let(:syntaxes) { :expect }

            let(:expected_source) do
              <<-END
                RSpec.configure do |config|
                  config.#{framework_block_method} :rspec do |#{block_arg_name}|
                    #{block_arg_name}.syntax = :expect
                  end
                end
              END
            end

            it "adds ##{framework_block_method} block " \
               'and #syntax= statement' do
              rewritten_source.should == expected_source
            end

            context 'when there are already some configurations' do
              let(:source) do
                <<-END
                  RSpec.configure do |config|
                    config.foo = 1
                  end
                END
              end

              let(:syntaxes) { :expect }

              let(:expected_source) do
                <<-END
                  RSpec.configure do |config|
                    config.foo = 1

                    config.#{framework_block_method} :rspec do |#{block_arg_name}|
                      #{block_arg_name}.syntax = :expect
                    end
                  end
                END
              end

              it 'adds the block after a blank line' do
                rewritten_source.should == expected_source
              end
            end
          end
        end
      end

      describe '#expectations' do
        subject { rspec_configure.expectations }

        include_examples '#syntaxes', :expect_with
        include_examples '#syntaxes=', :expect_with, :expectations
      end

      describe '#mocks' do
        subject(:mocks) { rspec_configure.mocks }

        include_examples '#syntaxes', :mock_with
        include_examples '#syntaxes=', :mock_with, :mocks

        describe '#yield_receiver_to_any_instance_implementation_blocks=' do
          before do
            mocks.yield_receiver_to_any_instance_implementation_blocks = value
          end

          context 'when #mock_with { #yield_receiver_to_any_instance_implementation_blocks= } exists' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |c|
                    c.yield_receiver_to_any_instance_implementation_blocks = foo
                  end
                end
              END
            end

            context 'when true is passed' do
              let(:value) { true }

              let(:expected_source) do
                <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |c|
                    c.yield_receiver_to_any_instance_implementation_blocks = true
                  end
                end
                END
              end

              it 'rewrites the setter argument to `true`' do
                rewritten_source.should == expected_source
              end
            end

            context 'when false is passed' do
              let(:value) { false }

              let(:expected_source) do
                <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |c|
                    c.yield_receiver_to_any_instance_implementation_blocks = false
                  end
                end
                END
              end

              it 'rewrites the setter argument to `false`' do
                rewritten_source.should == expected_source
              end
            end
          end

          context 'when #mock_with { #yield_receiver_to_any_instance_implementation_blocks= } does not exist' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |c|
                  end
                end
              END
            end

            let(:value) { true }

            let(:expected_source) do
              <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |c|
                    c.yield_receiver_to_any_instance_implementation_blocks = true
                  end
                end
              END
            end

            it 'adds #yield_receiver_to_any_instance_implementation_blocks= statement' do
              rewritten_source.should == expected_source
            end
          end

          context 'when #mock_with block does not exist' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                end
              END
            end

            let(:value) { true }

            let(:expected_source) do
              <<-END
                RSpec.configure do |config|
                  config.mock_with :rspec do |mocks|
                    mocks.yield_receiver_to_any_instance_implementation_blocks = true
                  end
                end
              END
            end

            it 'adds #mock_with block ' \
               'and #yield_receiver_to_any_instance_implementation_blocks= statement' do
              rewritten_source.should == expected_source
            end

            context "when RSpec.configure's block argument name is `mocks`" do
              let(:source) do
                <<-END
                  RSpec.configure do |mocks|
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  RSpec.configure do |mocks|
                    mocks.mock_with :rspec do |config|
                      config.yield_receiver_to_any_instance_implementation_blocks = true
                    end
                  end
                END
              end

              it 'defines #mock_with block argument name as `config`' do
                rewritten_source.should == expected_source
              end
            end
          end
        end
      end

      context 'when multiple configurations are added' do
        before do
          rspec_configure.expose_dsl_globally = true
          rspec_configure.mocks.yield_receiver_to_any_instance_implementation_blocks = false
        end

        let(:source) do
          <<-END
            RSpec.configure do |config|
            end
          END
        end

        let(:expected_source) do
          <<-END
            RSpec.configure do |config|
              config.expose_dsl_globally = true

              config.mock_with :rspec do |mocks|
                mocks.yield_receiver_to_any_instance_implementation_blocks = false
              end
            end
          END
        end

        it 'adds them properly' do
          rewritten_source.should == expected_source
        end
      end
    end
  end
end
