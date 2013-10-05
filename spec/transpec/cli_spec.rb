# coding: utf-8

require 'spec_helper'
require 'transpec/cli'

module Transpec
  describe CLI do
    include FileHelper

    subject(:cli) { CLI.new }

    describe '.run' do
      it 'invokes #run' do
        args = ['foo', 'bar']
        CLI.any_instance.should_receive(:run).with(args)
        CLI.run(args)
      end
    end

    describe '#forced?' do
      subject { cli.forced? }

      context 'by default' do
        it { should be_false }
      end
    end

    describe '#run' do
      before do
        cli.stub(:puts)
        cli.stub(:warn)
        cli.stub(:target_files).and_return(args)
      end

      subject { cli.run(args) }

      let(:args) { ['some_file.rb'] }

      let(:rewriter) do
        rewriter = double('rewriter').as_null_object
        rewriter.stub(:invalid_context_errors).and_return([])
        rewriter
      end

      shared_examples 'rewrites files' do
        it 'rewrites files' do
          rewriter.should_receive(:rewrite_file!)
          cli.run(args)
        end

        it 'returns true' do
          should be_true
        end
      end

      shared_context 'stubbed rewriter' do
        before do
          Rewriter.stub(:new).and_return(rewriter)
        end
      end

      context 'when git is available' do
        include_context 'stubbed rewriter'

        before { Git.stub(:command_available?).and_return(true) }

        context 'and inside of a repository' do
          before { Git.stub(:inside_of_repository?).and_return(true) }

          context 'and the repository is not clean' do
            before { Git.stub(:clean?).and_return(false) }

            context '#forced? is false' do
              before { cli.stub(:forced?).and_return(false) }

              it 'aborts processing' do
                rewriter.should_not_receive(:rewrite_file!)
                cli.run(args).should be_false
              end

              it 'warns to the user' do
                cli.should_receive(:warn) do |arg|
                  arg.should include('clean')
                end

                cli.run(args)
              end
            end

            context '#forced? is true' do
              before { cli.stub(:forced?).and_return(true) }
              include_examples 'rewrites files'
            end
          end

          context 'and the repository is clean' do
            before { Git.stub(:clean?).and_return(true) }
            include_examples 'rewrites files'
          end
        end

        context 'and not inside of a repository' do
          before { Git.stub(:inside_of_repository?).and_return(false) }
          include_examples 'rewrites files'
        end
      end

      context 'when git is not available' do
        include_context 'stubbed rewriter'
        before { Git.stub(:command_available?).and_return(false) }
        include_examples 'rewrites files'
      end

      context 'when a syntax error is raised while processing files' do
        include_context 'isolated environment'

        let(:args) { [invalid_syntax_file_path, valid_syntax_file_path] }
        let(:invalid_syntax_file_path) { 'invalid_example.rb' }
        let(:valid_syntax_file_path) { 'valid_example.rb' }

        before do
          create_file(invalid_syntax_file_path, 'This is invalid syntax <')
          create_file(valid_syntax_file_path, 'this_is_valid_syntax')
        end

        it 'warns to the user' do
          cli.should_receive(:warn) do |message|
            message.should include('Syntax error')
          end

          cli.run(args)
        end

        it 'continues processing files' do
          cli.should_receive(:puts).with("Processing #{invalid_syntax_file_path}")
          cli.should_receive(:puts).with("Processing #{valid_syntax_file_path}")
          cli.run(args)
        end
      end

      context 'when any other error is raised while running' do
        include_context 'stubbed rewriter'

        before do
          cli.stub(:parse_options).and_raise(ArgumentError, 'No such file or directory - non-existent-file')
        end

        it 'return false' do
          should be_false
        end

        it 'prints message of the exception' do
          cli.should_receive(:warn).with('No such file or directory - non-existent-file')
          cli.run([])
        end
      end

      context 'when no target paths are specified' do
        include_context 'isolated environment'
        include_context 'stubbed rewriter'

        let(:args) { [] }

        context 'and there is "spec" directory' do
          before { Dir.mkdir('spec') }

          it 'targets files in the "spec" directoy' do
            cli.should_receive(:target_files).with(['spec'])
            cli.run(args)
          end
        end

        context 'and there is not "spec" directory' do
          it 'aborts' do
            should be_false
          end
        end
      end
    end

    describe '#process_file' do
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
              class SomeClass
                def some_method
                  1.should == 1
                end
              end

              it 'is an example' do
                SomeClass.new.some_method
              end
            end
          END
        end

        it 'warns to user' do
          cli.should_receive(:warn) do |message|
            message.should =~ /cannot/i
            message.should =~ /context/i
          end

          cli.process_file(file_path)
        end
      end
    end

    describe '#parse_options' do
      subject { cli.parse_options(args) }
      let(:args) { ['some_file', '--negative-form', 'to_not', 'some_dir'] }

      it 'return non-option arguments' do
        should == ['some_file', 'some_dir']
      end

      it 'does not mutate the passed array' do
        cli.parse_options(args)
        args.should == ['some_file', '--negative-form', 'to_not', 'some_dir']
      end

      describe '-f/--force option' do
        let(:args) { ['--force'] }

        it 'sets #forced? true' do
          cli.parse_options(args)
          cli.should be_forced
        end
      end

      describe '-d/--disable option' do
        [
          ['expect_to_matcher', :convert_to_expect_to_matcher?],
          ['expect_to_receive', :convert_to_expect_to_receive?],
          ['allow_to_receive',  :convert_to_allow_to_receive?],
          ['deprecated',        :replace_deprecated_method?]
        ].each do |cli_type, config_attr|
          context "when #{cli_type.inspect} is specified" do
            let(:args) { ['--disable', cli_type] }

            it "sets Configuration##{config_attr} false" do
              cli.parse_options(args)
              cli.configuration.send(config_attr).should be_false
            end
          end
        end

        context 'when multiple types are specified with comma' do
          let(:args) { ['--disable', 'allow_to_receive,deprecated'] }

          it 'handles all of them' do
            cli.parse_options(args)
            cli.configuration.convert_to_allow_to_receive?.should be_false
            cli.configuration.replace_deprecated_method?.should be_false
          end
        end

        context 'when unknown type is specified' do
          let(:args) { ['--disable', 'unknown'] }

          it 'raises error' do
            -> { cli.parse_options(args) }.should raise_error(ArgumentError) { |error|
              error.message.should == 'Unknown conversion type "unknown"'
            }
          end
        end
      end

      describe '-n/--negative-form option' do
        ['not_to', 'to_not'].each do |form|
          context "when #{form.inspect} is specified" do
            let(:args) { ['--negative-form', form] }

            it "sets Configuration#negative_form_of_to? #{form.inspect}" do
              cli.parse_options(args)
              cli.configuration.negative_form_of_to.should == form
            end
          end
        end
      end

      describe '-p/--no-parentheses-matcher-arg option' do
        let(:args) { ['--no-parentheses-matcher-arg'] }

        it 'sets Configuration#parenthesize_matcher_arg? false' do
          cli.parse_options(args)
          cli.configuration.parenthesize_matcher_arg.should be_false
        end
      end

      describe '--no-color option' do
        before do
          Sickill::Rainbow.enabled = true
        end

        let(:args) { ['--no-color'] }

        it 'disables color in the output' do
          cli.parse_options(args)
          Sickill::Rainbow.enabled.should be_false
        end
      end

      describe '--version option' do
        before do
          cli.stub(:puts)
          cli.stub(:exit)
        end

        let(:args) { ['--version'] }

        it 'shows version' do
          cli.should_receive(:puts).with(Version.to_s)
          cli.parse_options(args)
        end

        it 'exits' do
          cli.should_receive(:exit)
          cli.parse_options(args)
        end
      end
    end

    describe '#target_files' do
      include_context 'isolated environment'

      before do
        ['file', 'file.rb', 'dir/file', 'dir/file.rb'].each do |path|
          create_file(path, '')
        end
      end

      subject(:target_files) { cli.target_files(paths) }

      context 'when no path is passed' do
        let(:paths) { [] }

        it 'returns empty array' do
          should be_empty
        end
      end

      context 'when a file path with .rb extension is passed' do
        let(:paths) { ['file.rb'] }

        it 'returns the path' do
          should == ['file.rb']
        end
      end

      context 'when a file path without extension is passed' do
        let(:paths) { ['file'] }

        it 'returns the path' do
          should == ['file']
        end
      end

      context 'when a non-existent path is passed' do
        let(:paths) { ['non-existent-file'] }

        it 'raises error' do
          -> { target_files }.should raise_error(ArgumentError) { |error|
            error.message.should == 'No such file or directory "non-existent-file"'
          }
        end
      end

      context 'when a directory path is passed' do
        let(:paths) { ['dir'] }

        it 'returns file paths with .rb extension in the directory recursively' do
          should == ['dir/file.rb']
        end
      end
    end
  end
end
