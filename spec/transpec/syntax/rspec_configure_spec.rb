# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/rspec_configure'

module Transpec
  class Syntax
    describe RSpecConfigure do
      include_context 'parsed objects'

      subject(:rspec_configure) do
        ast.each_node do |node|
          next unless RSpecConfigure.target_node?(node)
          return RSpecConfigure.new(node, source_rewriter)
        end
        fail 'No RSpec.configure node is found!'
      end

      [
        [:expectation_syntaxes, :expect_with, 'RSpec::Matchers::Configuration'],
        [:mock_syntaxes,        :mock_with,   'RSpec::Mocks::Configuration']
      ].each do |subject_method, config_block_method, framework_config_class|
        describe "##{subject_method}" do
          subject { rspec_configure.send(subject_method) }

          context 'when :should is enabled' do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{config_block_method} :rspec do |c|
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
                  config.#{config_block_method} :rspec do |c|
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
                  config.#{config_block_method} :rspec do |c|
                    c.syntax = some_syntax
                  end
                end
              END
            end

            it 'raises error' do
              -> { subject }.should raise_error(RSpecConfigure::UnknownSyntaxError)
            end
          end

          context "when RSpec::Core::Configuration##{config_block_method} block does not exist" do
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

          context "when #{framework_config_class}#syntax= does not exist" do
            let(:source) do
              <<-END
                RSpec.configure do |config|
                  config.#{config_block_method} :rspec do |c|
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

      [
        [:modify_expectation_syntaxes!, :expect_with, 'RSpec::Matchers::Configuration'],
        [:modify_mock_syntaxes!,        :mock_with,   'RSpec::Mocks::Configuration']
      ].each do |subject_method, config_block_method, framework_config_class|
        describe "##{subject_method}" do
          before do
            rspec_configure.send(subject_method, syntaxes)
          end

          let(:source) do
            <<-END
              RSpec.configure do |config|
                config.#{config_block_method} :rspec do |c|
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
                config.#{config_block_method} :rspec do |c|
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
                config.#{config_block_method} :rspec do |c|
                  c.syntax = [:should, :expect]
                end
              end
            END
            end

            it 'rewrites syntax specification to `c.syntax = [:should, :expect]`' do
              rewritten_source.should == expected_source
            end
          end

          context 'when RSpec::Core::Configuration#expect_with block does not exist' do
            pending
          end

          context "when #{framework_config_class}#syntax= does not exist" do
            pending
          end
        end
      end
    end
  end
end
