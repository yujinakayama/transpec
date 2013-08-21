# coding: utf-8

require 'spec_helper'
require 'transpec/rewriter'

module Transpec
  describe Rewriter do
    subject(:rewriter) { Rewriter.new(configuration) }
    let(:configuration) { Configuration.new }

    describe '#rewrite_file!' do
      include_context 'isolated environment'

      let(:file_path) { 'sample_spec.rb' }

      before do
        File.write(file_path, 'This is a spec')
        rewriter.stub(:rewrite).and_return('This is the rewritten spec')
      end

      it 'overwrites the passed file path' do
        rewriter.rewrite_file!(file_path)
        File.read(file_path).should == 'This is the rewritten spec'
      end
    end

    describe '#rewrite' do
      subject { rewriter.rewrite(source) }

      let(:source) do
        <<-END
          RSpec.configure do |config|
            config.expect_with :rspec do |c|
              c.syntax = :should
            end

            config.mock_with :rspec do |c|
              c.syntax = :should
            end
          end

          describe 'example group' do
            it 'is an example' do
              something = mock('something')
              something.stub!(:message)
              something.should_receive(:message)
              something.should_not == 'foo'
              expect(1.0 / 3.0).to be_close(0.333, 0.001)
            end
          end
        END
      end

      context 'when Configuration#convert_to_expect_to_matcher? is true' do
        before { configuration.convert_to_expect_to_matcher = true }

        context 'and Configuration#negative_form_of_to is "not_to"' do
          before { configuration.negative_form_of_to = 'not_to' }

          it 'invokes Should#expectize! with "not_to"' do
            Syntax::Should.any_instance.should_receive(:expectize!).with('not_to', anything)
            rewriter.rewrite(source)
          end
        end

        context 'and Configuration#negative_form_of_to is "to_not"' do
          before { configuration.negative_form_of_to = 'to_not' }

          it 'invokes Should#expectize! with "to_not"' do
            Syntax::Should.any_instance.should_receive(:expectize!).with('to_not', anything)
            rewriter.rewrite(source)
          end
        end

        context 'and Configuration#parenthesize_matcher_arg is true' do
          before { configuration.parenthesize_matcher_arg = true }

          it 'invokes Should#expectize! with true as second argument' do
            Syntax::Should.any_instance.should_receive(:expectize!).with(anything, true)
            rewriter.rewrite(source)
          end
        end

        context 'and Configuration#parenthesize_matcher_arg is false' do
          before { configuration.parenthesize_matcher_arg = false }

          it 'invokes Should#expectize! with false as second argument' do
            Syntax::Should.any_instance.should_receive(:expectize!).with(anything, false)
            rewriter.rewrite(source)
          end
        end
      end

      context 'when Configuration#convert_to_expect_to_matcher? is false' do
        before { configuration.convert_to_expect_to_matcher = false }

        it 'does not invoke Should#expectize!' do
          Syntax::Should.any_instance.should_not_receive(:expectize!)
          rewriter.rewrite(source)
        end
      end

      context 'when Configuration#convert_to_expect_to_receive? is true' do
        before { configuration.convert_to_expect_to_receive = true }

        context 'and Configuration#negative_form_of_to is "not_to"' do
          before { configuration.negative_form_of_to = 'not_to' }

          it 'invokes ShouldReceive#expectize! with "not_to"' do
            Syntax::ShouldReceive.any_instance.should_receive(:expectize!).with('not_to')
            rewriter.rewrite(source)
          end
        end

        context 'and Configuration#negative_form_of_to is "to_not"' do
          before { configuration.negative_form_of_to = 'to_not' }

          it 'invokes ShouldReceive#expectize! with "to_not"' do
            Syntax::ShouldReceive.any_instance.should_receive(:expectize!).with('to_not')
            rewriter.rewrite(source)
          end
        end
      end

      context 'when Configuration#convert_to_expect_to_receive? is false' do
        before { configuration.convert_to_expect_to_receive = false }

        it 'does not invoke ShouldReceive#expectize!' do
          Syntax::ShouldReceive.any_instance.should_not_receive(:expectize!)
          rewriter.rewrite(source)
        end
      end

      context 'when Configuration#convert_to_allow_to_receive? is true' do
        before { configuration.convert_to_allow_to_receive = true }

        it 'invokes MethodStub#allowize!' do
          Syntax::MethodStub.any_instance.should_receive(:allowize!)
          rewriter.rewrite(source)
        end
      end

      context 'when Configuration#convert_to_allow_to_receive? is false' do
        before { configuration.convert_to_allow_to_receive = false }

        it 'does not invoke MethodStub#allowize!' do
          Syntax::MethodStub.any_instance.should_not_receive(:allowize!)
          rewriter.rewrite(source)
        end
      end

      context 'when Configuration#replace_deprecated_method? is true' do
        before { configuration.replace_deprecated_method = true }

        it 'invokes Double#convert_to_double!' do
          Syntax::Double.any_instance.should_receive(:convert_to_double!)
          rewriter.rewrite(source)
        end

        it 'invokes BeClose#convert_to_be_within!' do
          Syntax::BeClose.any_instance.should_receive(:convert_to_be_within!)
          rewriter.rewrite(source)
        end
      end

      context 'when Configuration#replace_deprecated_method? is true' do
        before { configuration.replace_deprecated_method = false }

        it 'does not invoke Double#convert_to_double!' do
          Syntax::Double.any_instance.should_not_receive(:convert_to_double!)
          rewriter.rewrite(source)
        end

        it 'does not invoke BeClose#convert_to_be_within!' do
          Syntax::BeClose.any_instance.should_not_receive(:convert_to_be_within!)
          rewriter.rewrite(source)
        end
      end

      context 'when #need_to_modify_expectation_syntax_configuration? returns true' do
        before do
          rewriter.stub(:need_to_modify_expectation_syntax_configuration?).and_return(true)
        end

        it 'invokes RSpecConfigure#modify_expectation_syntaxes! with :expect' do
          Syntax::RSpecConfigure.any_instance
            .should_receive(:modify_expectation_syntaxes!).with(:expect)
          rewriter.rewrite(source)
        end
      end

      context 'when #need_to_modify_expectation_syntax_configuration? returns false' do
        before do
          rewriter.stub(:need_to_modify_expectation_syntax_configuration?).and_return(false)
        end

        it 'does not invoke RSpecConfigure#modify_expectation_syntaxes!' do
          Syntax::RSpecConfigure.any_instance.should_not_receive(:modify_expectation_syntaxes!)
          rewriter.rewrite(source)
        end
      end

      context 'when #need_to_modify_mock_syntax_configuration? returns true' do
        before do
          rewriter.stub(:need_to_modify_mock_syntax_configuration?).and_return(true)
        end

        it 'invokes RSpecConfigure#modify_mock_syntaxes! with :expect' do
          Syntax::RSpecConfigure.any_instance
            .should_receive(:modify_mock_syntaxes!).with(:expect)
          rewriter.rewrite(source)
        end
      end

      context 'when #need_to_modify_mock_syntax_configuration? returns false' do
        before do
          rewriter.stub(:need_to_modify_mock_syntax_configuration?).and_return(false)
        end

        it 'does not invoke RSpecConfigure#modify_mock_syntaxes!' do
          Syntax::RSpecConfigure.any_instance.should_not_receive(:modify_mock_syntaxes!)
          rewriter.rewrite(source)
        end
      end

      context 'when the source have overlapped rewrite targets' do
        let(:source) do
          <<-END
            describe 'example group' do
              it 'is an example' do
                object.stub(:message => mock('something'))
              end
            end
          END
        end

        let(:expected_source) do
          <<-END
            describe 'example group' do
              it 'is an example' do
                allow(object).to receive(:message).and_return(double('something'))
              end
            end
          END
        end

        it 'rewrites all targets properly' do
          should == expected_source
        end
      end

      context 'when the source have a monkey-patched expectation outside of example group context' do
        before do
          configuration.convert_to_expect_to_matcher = true
          rewriter.stub(:warn)
        end

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

        it 'does not rewrite the expectation to non-monkey-patch syntax' do
          should == source
        end

        it 'warns to user' do
          rewriter.should_receive(:warn) do |message|
            message.should =~ /cannot/i
            message.should =~ /context/i
          end

          rewriter.rewrite(source)
        end
      end
    end

    shared_examples 'syntaxes' do |syntaxes_reader, expectations|
      expectations.each do |current_syntaxes, return_value|
        context "and RSpecConfigure##{syntaxes_reader} returns #{current_syntaxes.inspect}" do
          before do
            rspec_configure.stub(syntaxes_reader).and_return(current_syntaxes)
          end

          it "returns #{return_value}" do
            should == return_value
          end
        end
      end
    end

    describe '#need_to_modify_expectation_syntax_configuration?' do
      subject { rewriter.need_to_modify_expectation_syntax_configuration?(rspec_configure) }
      let(:rspec_configure) { double('rspec_configure') }

      context 'when Configuration#convert_to_expect_to_matcher? is true' do
        before { configuration.convert_to_expect_to_matcher = true }

        include_examples 'syntaxes', :expectation_syntaxes, {
          []                 => false,
          [:should]          => true,
          [:expect]          => false,
          [:should, :expect] => false
        }
      end

      context 'when Configuration#convert_to_expect_to_matcher? is false' do
        before { configuration.convert_to_expect_to_matcher = false }

        include_examples 'syntaxes', :expectation_syntaxes, {
          []                 => false,
          [:should]          => false,
          [:expect]          => false,
          [:should, :expect] => false
        }
      end
    end

    describe '#need_to_modify_mock_syntax_configuration?' do
      subject { rewriter.need_to_modify_mock_syntax_configuration?(rspec_configure) }
      let(:rspec_configure) { double('rspec_configure') }

      context 'when Configuration#convert_to_expect_to_receive? is true' do
        before { configuration.convert_to_expect_to_receive = true }

        context 'and Configuration#convert_to_allow_to_receive? is true' do
          before { configuration.convert_to_allow_to_receive = true }

          include_examples 'syntaxes', :mock_syntaxes, {
            []                 => false,
            [:should]          => true,
            [:expect]          => false,
            [:should, :expect] => false
          }
        end

        context 'and Configuration#convert_to_allow_to_receive? is false' do
          before { configuration.convert_to_allow_to_receive = false }

          include_examples 'syntaxes', :mock_syntaxes, {
            []                 => false,
            [:should]          => true,
            [:expect]          => false,
            [:should, :expect] => false
          }
        end
      end

      context 'when Configuration#convert_to_expect_to_receive? is false' do
        before { configuration.convert_to_expect_to_receive = false }

        context 'and Configuration#convert_to_allow_to_receive? is true' do
          before { configuration.convert_to_allow_to_receive = true }

          include_examples 'syntaxes', :mock_syntaxes, {
            []                 => false,
            [:should]          => true,
            [:expect]          => false,
            [:should, :expect] => false
          }
        end

        context 'and Configuration#convert_to_allow_to_receive? is false' do
          before { configuration.convert_to_allow_to_receive = false }

          include_examples 'syntaxes', :mock_syntaxes, {
            []                 => false,
            [:should]          => false,
            [:expect]          => false,
            [:should, :expect] => false
          }
        end
      end
    end
  end
end
