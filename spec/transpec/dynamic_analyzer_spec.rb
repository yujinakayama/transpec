# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer'

module Transpec
  describe DynamicAnalyzer do
    include FileHelper
    include ::AST::Sexp
    include_context 'isolated environment'

    subject(:dynamic_analyzer) { DynamicAnalyzer.new(rspec_command: rspec_command, silent: true) }
    let(:rspec_command) { nil }

    describe '#rspec_command' do
      subject { dynamic_analyzer.rspec_command }

      context 'when command is specified' do
        let(:rspec_command) { 'rspec some_argument' }

        it 'returns the specified command' do
          should == rspec_command
        end
      end

      context 'when command is not specified' do
        context 'and there is a Gemfile' do
          before do
            create_file('Gemfile', '')
          end

          it 'returns "bundle exec rspec"' do
            should == 'bundle exec rspec'
          end
        end

        context 'and there is no Gemfile' do
          it 'returns "rspec"' do
            should == 'rspec'
          end
        end
      end
    end

    describe '#analyze' do
      let(:source) do
        <<-END
          describe [1, 2] do
            let(:foo) { [2, 1] }

            it 'matches to foo' do
              subject.should =~ foo
            end
          end
        END
      end

      let(:file_path) { 'spec/example_spec.rb' }

      before do
        create_file(file_path, source)
      end

      runtime_data_cache = {}

      subject(:runtime_data) do
        if runtime_data_cache[source]
          runtime_data_cache[source]
        else
          runtime_data_cache[source] = dynamic_analyzer.analyze
        end
      end

      it 'returns an instance of DynamicAnalyzer::RuntimeData' do
        runtime_data.should be_an(DynamicAnalyzer::RuntimeData)
      end

      describe 'its element' do
        let(:ast) do
          source_buffer = Parser::Source::Buffer.new(file_path)
          source_buffer.source = source

          builder = AST::Builder.new

          parser = Parser::CurrentRuby.new(builder)
          parser.parse(source_buffer)
        end

        let(:target_node) do
          ast.each_descendent_node do |node|
            return node if node == s(:send, nil, :foo)
          end
        end

        subject(:element) { runtime_data[target_node] }

        it 'is a hash' do
          should be_a(Hash)
        end

        it 'has result of requested analysis' do
          element[:class_name].should == 'Array'
        end

        it 'has class name of the context' do
          element[:context_class_name].should start_with('RSpec::Core::ExampleGroup::Nested_')
        end
      end
    end
  end
end
