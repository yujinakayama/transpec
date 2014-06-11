# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer'

module Transpec
  describe DynamicAnalyzer do
    include FileHelper
    include ::AST::Sexp
    include_context 'isolated environment'

    def find_node_in_file(file_path, &block)
      processed_source = ProcessedSource.parse_file(file_path)
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
          -> { dynamic_analyzer.analyze }.should raise_error(DynamicAnalyzer::AnalysisError)
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

    describe '#copy_recursively' do
      it 'copies files recursively' do
        [
          'src/file1',
          'src/file2',
          'src/dir1/file',
          'src/dir2/file'
        ].each do |path|
          create_file(path, '')
        end

        dynamic_analyzer.copy_recursively('src', 'dst')

        [
          'dst/file1',
          'dst/file2',
          'dst/dir1/file',
          'dst/dir2/file'
        ].each do |path|
          File.exist?(path).should be_true
        end
      end

      it 'copies only directories, files and symlinks' do
        create_file('src/file', '')
        File.symlink('file', 'src/symlink')
        Dir.mkdir('src/dir')
        system('mkfifo', 'src/fifo')

        dynamic_analyzer.copy_recursively('src', 'dst')

        File.file?('dst/file').should be_true
        File.symlink?('dst/symlink').should be_true
        File.directory?('dst/dir').should be_true
        File.exist?('dst/fifo').should be_false
      end

      def permission(path)
        format('%o', File.lstat(path).mode)[-4..-1]
      end

      it 'preserves permission' do
        create_file('src/file', '')
        File.chmod(0755, 'src/file')

        File.symlink('file', 'src/symlink')

        Dir.mkdir('src/dir')
        File.chmod(0600, 'src/dir')

        dynamic_analyzer.copy_recursively('src', 'dst')

        permission('dst/file').should == '0755'
        permission('dst/dir').should == '0600'
      end
    end
  end
end
