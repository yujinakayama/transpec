# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer'

module Transpec
  describe DynamicAnalyzer do
    include FileHelper
    include ::AST::Sexp
    include_context 'isolated environment'

    def find_node_in_file(file_path, &block)
      processed_source = ProcessedSource.from_file(file_path)
      processed_source.ast.each_node.find(&block)
    end

    subject(:dynamic_analyzer) { DynamicAnalyzer.new(rspec_command: rspec_command, silent: true) }
    let(:rspec_command) { nil }

    describe '.new' do
      context 'when block is passed' do
        it 'yields the instance' do
          yielded = false

          DynamicAnalyzer.new(silent: true) do |analyzer|
            yielded = true
            analyzer.should be_a(DynamicAnalyzer)
          end

          yielded.should be_true
        end

        it 'changes working directory to copied project directory' do
          initial_directory = Dir.pwd
          DynamicAnalyzer.new(silent: true) do
            Dir.pwd.should_not == initial_directory
          end
        end
      end
    end

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
      before do
        create_file(spec_file_path, source)
      end

      let(:spec_file_path) { 'spec/example_spec.rb' }

      let(:source) do
        <<-END
          describe [1, 2] do
            it 'has 2 items' do
              expect(subject).to have(2).items
            end
          end
        END
      end

      context 'when already in copied project directory' do
        it 'does not change working directory' do
          DynamicAnalyzer.new(silent: true) do |analyzer|
            Dir.should_not_receive(:chdir)
            analyzer.analyze
          end
        end
      end

      context 'when no path is passed' do
        it 'rewrites all files in the "spec" directory' do
          DynamicAnalyzer::Rewriter.any_instance.should_receive(:rewrite_file!) do |spec|
            spec.path.should == spec_file_path
          end

          dynamic_analyzer.analyze
        end
      end

      context 'when some paths are passed' do
        before do
          create_file('spec/another_spec.rb', '')
        end

        it 'rewrites only files in the passed paths' do
          DynamicAnalyzer::Rewriter.any_instance.should_receive(:rewrite_file!) do |spec|
            spec.path.should == spec_file_path
          end

          dynamic_analyzer.analyze([spec_file_path])
        end
      end

      context 'when there is invalid syntax source file' do
        before do
          create_file('spec/fixtures/invalid.rb', 'This is invalid syntax <')
        end

        it 'does not raise error' do
          -> { dynamic_analyzer.analyze }.should_not raise_error
        end
      end

      context 'when rspec did not pass' do
        let(:source) do
          <<-END
            describe [1, 2] do
              it 'has 2 items' do
                expect(subject).to have(1).items
              end
            end
          END
        end

        it 'does not raise error' do
          -> { dynamic_analyzer.analyze }.should_not raise_error
        end
      end

      context 'when analysis result data file is not found' do
        let(:source) { 'exit!' }

        it 'raises AnalysisError' do
          -> { dynamic_analyzer.analyze }
            .should raise_error(DynamicAnalyzer::AnalysisError, /Failed running dynamic analysis/)
        end
      end

      context 'when working directory has been changed at exit of rspec' do
        let(:source) { "Dir.chdir('spec')" }

        it 'does not raise error' do
          -> { dynamic_analyzer.analyze }.should_not raise_error
        end
      end

      context 'when rspec is run via rake task' do
        before do
          create_file('Rakefile', <<-END)
            require 'rspec/core/rake_task'
            RSpec::Core::RakeTask.new(:spec)
          END
        end

        let(:rspec_command) { 'rake spec' }

        it 'does not raise error' do
          -> { dynamic_analyzer.analyze }.should_not raise_error
        end
      end

      context 'when there is a .rspec file containing `--require spec_helper`' do
        before do
          create_file('.rspec', '--require spec_helper')
        end

        context 'and the spec/spec_helper.rb contains some code that is dynamic analysis target' do
          before do
            create_file('spec/spec_helper.rb', <<-END)
              RSpec.configure { }

              def some_helper_method_used_in_each_spec
              end
            END
          end

          let(:source) do
            <<-END
              some_helper_method_used_in_each_spec

              describe 'something' do
              end
            END
          end

          it 'does not raise error' do
            -> { dynamic_analyzer.analyze }.should_not raise_error
          end

          it 'preserves the existing `--require`' do
            describe_node = find_node_in_file(spec_file_path) do |node|
              node.send_type? && node.children[1] == :describe
            end

            runtime_data = dynamic_analyzer.analyze
            runtime_data.run?(describe_node).should be_true
          end
        end
      end

      context 'when there is a proxy/delegator Class that undefines Object methods' do
        let(:source) do
          # https://github.com/thoughtbot/factory_girl/blob/v4.4.0/lib/factory_girl/definition_proxy.rb#L3-L7
          <<-END
            class SomeProxy
              UNPROXIED_METHODS = %w(__send__ object_id initialize instance_eval).map(&:to_sym)

              (instance_methods + private_instance_methods).each do |method|
                undef_method(method) unless UNPROXIED_METHODS.include?(method)
              end
            end

            describe 'example' do
              it 'is 1' do
                proxy = SomeProxy.new
                proxy.instance_eval do
                  1.should == 1
                end
              end
            end
          END
        end

        it 'properly analyzes even in such context' do
          should_node = find_node_in_file(spec_file_path) do |node|
            node.send_type? && node.children[1] == :should
          end

          runtime_data = dynamic_analyzer.analyze
          runtime_data.run?(should_node).should be_true
        end
      end

      context 'when a deprecated syntax is used with `RSpec.configure { |c| c.raise_errors_for_deprecations! }`' do
        include CacheHelper

        around do |example|
          with_cached_dir('rspec-2.99-project') do |cached|
            unless cached
              create_file('Gemfile', <<-END)
                source 'https://rubygems.org'
                gem 'rspec', '~> 2.99'
              END

              Project.new.with_bundler_clean_env do
                `bundle install --path vendor/bundle`
              end

              create_file('spec/spec_helper.rb', <<-END)
                RSpec.configure do |config|
                  config.raise_errors_for_deprecations!
                end
              END
            end

            example.run
          end
        end

        let(:source) do
          <<-END
            require 'spec_helper'

            describe 'example' do
              it 'is deprecated syntax' do
                mock('something')
              end
            end
          END
        end

        it 'raises AnalysisError with a warning message about `raise_errors_for_deprecations!`' do
          -> { dynamic_analyzer.analyze }
            .should raise_error(DynamicAnalyzer::AnalysisError, /raise_errors_for_deprecations!/)
        end
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

      describe 'an element of the runtime data' do
        let(:target_node) do
          find_node_in_file(spec_file_path) do |node|
            node == s(:send, nil, :subject)
          end
        end

        subject(:element) { runtime_data[target_node] }

        it 'is an OpenStruct' do
          should be_a(OpenStruct)
        end

        it 'has result of requested analysis' do
          element[:available_query_methods].should =~ %w(size count length)
        end
      end
    end
  end
end
