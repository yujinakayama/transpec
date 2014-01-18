# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/rspec_configure'

module Transpec
  class Syntax
    describe RSpecConfigure do
      include_context 'parsed objects'
      include_context 'syntax object', RSpecConfigure, :rspec_configure

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

      shared_examples '#syntaxes=' do |framework_block_method|
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

          context "when ##{framework_block_method} block does not exist" do
            pending
          end

          context "when ##{framework_block_method} { #syntax= } does not exist" do
            pending
          end
        end
      end

      describe '#expectations' do
        subject { rspec_configure.expectations }

        include_examples '#syntaxes', :expect_with
        include_examples '#syntaxes=', :expect_with
      end

      describe '#mocks' do
        subject { rspec_configure.mocks }

        include_examples '#syntaxes', :mock_with
        include_examples '#syntaxes=', :mock_with
      end
    end
  end
end
