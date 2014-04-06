# coding: utf-8

require 'spec_helper'
require 'transpec/cli'

module Transpec
  describe CLI do
    include FileHelper

    subject(:cli) { CLI.new }

    before do
      cli.project.stub(:rspec_version).and_return(Transpec.required_rspec_version)
    end

    describe '.run' do
      it 'invokes #run' do
        args = ['foo', 'bar']
        CLI.any_instance.should_receive(:run).with(args)
        CLI.run(args)
      end
    end

    describe '#run' do
      include_context 'isolated environment'

      subject { cli.run(args) }

      let(:args) { [file_path] }
      let(:file_path) { 'spec/example_spec.rb' }
      let(:file_content) do
        <<-END
          describe 'something' do
            it 'is 1' do
              1.should == 1
            end
          end
        END
      end

      before do
        cli.stub(:puts)
        cli.stub(:warn)
        DynamicAnalyzer.any_instance.stub(:analyze).and_return(DynamicAnalyzer::RuntimeData.new)
        create_file(file_path, file_content)
      end

      shared_examples 'rewrites files' do
        it 'rewrites files' do
          cli.should_receive(:convert_file)
          cli.run(args)
        end

        it 'returns true' do
          should be_true
        end
      end

      shared_examples 'aborts processing' do
        it 'aborts processing' do
          cli.should_not_receive(:convert_file)
          cli.run(args).should be_false
        end
      end

      shared_examples 'generates commit message' do
        it 'generates commit message to .git/COMMIT_EDITMSG' do
          cli.run(args)
          File.read('.git/COMMIT_EDITMSG').should start_with('Convert specs')
        end
      end

      shared_examples 'does not generate commit message' do
        it 'does not generate commit message' do
          cli.run(args)
          File.exist?('.git/COMMIT_EDITMSG').should be_false
        end
      end

      context 'when git is available' do
        before { Git.stub(:command_available?).and_return(true) }

        context 'and inside of a repository' do
          include_context 'inside of git repository'

          context 'and the repository is not clean' do
            before { Git.stub(:clean?).and_return(false) }

            context 'and --force option is not specified' do
              include_examples 'aborts processing'
              include_examples 'does not generate commit message'

              it 'warns to the user' do
                cli.should_receive(:warn) do |arg|
                  arg.should include('clean')
                end

                cli.run(args)
              end
            end

            context 'and --force option is specified' do
              before { args << '--force' }
              include_examples 'rewrites files'
              include_examples 'generates commit message'
            end
          end

          context 'and the repository is clean' do
            before { Git.stub(:clean?).and_return(true) }

            include_examples 'rewrites files'
            include_examples 'generates commit message'

            context 'and no conversion is done' do
              let(:file_content) { '' }
              include_examples 'does not generate commit message'
            end
          end
        end

        context 'and not inside of a repository' do
          include_examples 'rewrites files'
          include_examples 'does not generate commit message'
        end
      end

      context 'when git is not available' do
        before { Git.stub(:command_available?).and_return(false) }
        include_examples 'rewrites files'
        include_examples 'does not generate commit message'
      end

      context "when the project's RSpec dependency is older than the required version" do
        before do
          Git.stub(:command_available?).and_return(false)
          cli.project.stub(:rspec_version).and_return(RSpecVersion.new('2.13.0'))
        end

        include_examples 'aborts processing'

        it 'warns to the user' do
          cli.should_receive(:warn) do |arg|
            arg.should match(/rspec.+dependency/i)
          end

          cli.run(args)
        end
      end

      context 'when analysis error is raised in the dynamic analysis' do
        before do
          Git.stub(:command_available?).and_return(false)
          DynamicAnalyzer.any_instance.stub(:analyze).and_raise(DynamicAnalyzer::AnalysisError)
        end

        include_examples 'aborts processing'

        it 'suggests using -c/--rspec-command option' do
          cli.should_receive(:warn) do |message|
            message.should include('use -c/--rspec-command')
          end

          cli.run(args)
        end
      end

      context 'when a syntax error is raised while processing files' do
        let(:args) { [invalid_syntax_file_path, valid_syntax_file_path] }
        let(:invalid_syntax_file_path) { 'spec/invalid_example.rb' }
        let(:valid_syntax_file_path) { 'spec/valid_example.rb' }

        before do
          create_file(invalid_syntax_file_path, 'This is invalid syntax <')
          create_file(valid_syntax_file_path, 'this_is_valid_syntax')
        end

        it 'warns to the user' do
          cli.should_receive(:warn)
            .with('Syntax error at spec/invalid_example.rb:2:1. Skipping the file.')
          cli.run(args)
        end

        it 'continues processing files' do
          cli.should_receive(:puts).with("Converting #{invalid_syntax_file_path}")
          cli.should_receive(:puts).with("Converting #{valid_syntax_file_path}")
          cli.run(args)
        end
      end

      context 'when any other error is raised while running' do
        let(:args) { ['non-existent-file'] }

        it 'does not catch the error' do
          -> { cli.run(args) }.should raise_error
        end
      end

      context 'when -s/--skip-dynamic-analysis option is specified' do
        let(:args) { ['--skip-dynamic-analysis', file_path] }

        it 'skips dynamic analysis' do
          DynamicAnalyzer.any_instance.should_not_receive(:analyze)
          cli.should_receive(:convert_file)
          cli.run(args)
        end
      end

      context 'when -c/--rspec-command option is specified' do
        include_context 'inside of git repository'

        let(:args) { ['--force', '--rspec-command', 'rspec --profile'] }

        it 'passes the command to DynamicAnalyzer' do
          DynamicAnalyzer.should_receive(:new) do |arg|
            arg[:rspec_command].should == 'rspec --profile'
          end.and_call_original

          cli.run(args)
        end
      end
    end

    describe '#convert_file' do
      include_context 'isolated environment'

      let(:file_path) { 'example.rb' }

      before do
        create_file(file_path, source)
        cli.stub(:puts)
      end

      context 'when the source has a monkey-patched expectation outside of example group context' do
        let(:source) do
          <<-END
            describe 'example group' do
              class Klass
                def some_method
                  1.should == 1
                end
              end

              it 'is an example' do
                Klass.new.some_method
              end
            end
          END
        end

        it 'warns to user' do
          cli.should_receive(:warn) do |message|
            message.should =~ /cannot/i
            message.should =~ /context/i
          end

          cli.convert_file(file_path)
        end
      end

      context 'when it did a less accurate conversion due to a lack of runtime information' do
        let(:source) do
          <<-END
            describe 'example group' do
              it 'is an example' do
                expect(obj).to have(2).items
              end
            end
          END
        end

        it 'warns to user' do
          cli.should_receive(:warn) do |message|
            message.should =~ /converted.+but.+incorrect/i
          end

          cli.convert_file(file_path)
        end
      end

      context 'when both conversion errors and less accurate records are reported' do
        let(:source) do
          <<-END
            describe 'example group' do
              it 'is first' do
                expect(obj).to have(1).item
              end

              class Klass
                def second
                  2.should == 2
                end
              end

              it 'is an example' do
                Klass.new.some_method
              end

              it 'is third' do
                expect(obj).to have(3).items
              end
            end
          END
        end

        it 'displays them in order of line number' do
          times = 1

          cli.should_receive(:warn).exactly(3).times do |message|
            line_number = case times
                          when 1 then 3
                          when 2 then 8
                          when 3 then 17
                          end
            message.should include(":#{line_number}:")
            times += 1
          end

          cli.convert_file(file_path)
        end
      end
    end
  end
end
