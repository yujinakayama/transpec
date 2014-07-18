# coding: utf-8

require 'spec_helper'
require 'transpec/converter'

module Transpec
  describe Converter do
    subject(:converter) { Converter.new(spec_suite, config, rspec_version) }
    let(:spec_suite) { double('spec_suite', runtime_data: nil).as_null_object }
    let(:config) { Config.new }
    let(:rspec_version) { Transpec.required_rspec_version }

    describe '#convert_file!' do
      include_context 'isolated environment'

      let(:file_path) { 'sample_spec.rb' }

      before do
        File.write(file_path, 'This is a spec')
        File.utime(0, 0, file_path)
        converter.stub(:rewrite).and_return('This is the converted spec')
      end

      context 'when a file path is passed' do
        it 'overwrites the file' do
          converter.convert_file!(file_path)
          File.read(file_path).should == 'This is the converted spec'
        end
      end

      context 'when a processed source is passed' do
        let(:processed_source) { ProcessedSource.from_file(file_path) }

        it 'overwrites the file that the processed source was derived from' do
          converter.convert_file!(processed_source)
          File.read(file_path).should == 'This is the converted spec'
        end
      end

      context 'when the source is not needed to be converted' do
        before do
          converter.stub(:rewrite).and_return('This is a spec')
        end

        it 'does not touch the file' do
          converter.convert_file!(file_path)
          File.mtime(file_path).should == Time.at(0)
        end
      end
    end

    describe '#convert_source' do
      subject { converter.convert_source(source) }

      let(:source) do
        <<-END
          describe 'example group' do
            it 'is an example' do
              something.should == 'foo'
              something.should_receive(:message)
            end
          end
        END
      end

      it 'dispatches conversion target standalone syntax objects to each handler method' do
        converter.should_receive(:process_should).with(an_instance_of(Syntax::Should))
        converter.should_receive(:process_should_receive).with(an_instance_of(Syntax::ShouldReceive))
        converter.should_not_receive(:process_stub)
        converter.convert_source(source)
      end

      it 'dispatches conversion target non-standalone syntax objects to each handler method' do
        converter.should_receive(:process_operator).with(an_instance_of(Syntax::Operator))
        converter.should_not_receive(:process_have)
        converter.should_not_receive(:process_raise_error)
        converter.convert_source(source)
      end

      context 'when the source is invalid' do
        let(:source) { '<' }

        it 'raises Parser::SyntaxError' do
          -> { converter.convert_source(source) }.should raise_error(Parser::SyntaxError)
        end
      end

      context 'when the source has overlapped conversion targets' do
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

        before do
          config.convert_stub_with_hash_to_allow_to_receive_and_return = true
        end

        it 'converts all targets properly' do
          should == expected_source
        end

        it 'adds records for only completed conversions' do
          converter.convert_source(source)
          converter.report.records.count.should == 2
        end
      end

      context 'when the source has a monkey-patched expectation outside of example group context' do
        before do
          config.convert_should = true
          converter.stub(:warn)
        end

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

        it 'does not convert the expectation to non-monkey-patch syntax' do
          should == source
        end

        it 'adds the conversion error to the report' do
          converter.convert_source(source)
          converter.report.should have(1).conversion_error
        end
      end
    end

    describe '#process_should' do
      let(:should_object) { double('should_object', raise_error_matcher: raise_error_object).as_null_object }
      let(:raise_error_object) { double('raise_error_object').as_null_object }

      context 'when Config#convert_should? is true' do
        before { config.convert_should = true }

        context 'and Config#negative_form_of_to is "not_to"' do
          before { config.negative_form_of_to = 'not_to' }

          it 'invokes Should#expectize! with "not_to"' do
            should_object.should_receive(:expectize!).with('not_to')
            converter.process_should(should_object)
          end
        end

        context 'and Config#negative_form_of_to is "to_not"' do
          before { config.negative_form_of_to = 'to_not' }

          it 'invokes Should#expectize! with "to_not"' do
            should_object.should_receive(:expectize!).with('to_not')
            converter.process_should(should_object)
          end
        end
      end

      context 'when Config#convert_should? is false' do
        before { config.convert_should = false }

        it 'does not invoke Should#expectize!' do
          should_object.should_not_receive(:expectize!)
          converter.process_should(should_object)
        end
      end
    end

    describe '#process_oneliner_should' do
      let(:should_object) do
        double(
          'oneliner_should_object',
          raise_error_matcher: raise_error_object,
                 have_matcher: have_object
        ).as_null_object
      end

      let(:raise_error_object) { double('raise_error_object').as_null_object }
      let(:have_object) { double('have_object').as_null_object }

      shared_examples 'does nothing' do
        it 'does nothing' do
          should_object.should_not_receive(:expectize!)
          should_object.should_not_receive(:convert_have_items_to_standard_should!)
          should_object.should_not_receive(:convert_have_items_to_standard_expect!)
          converter.process_oneliner_should(should_object)
        end
      end

      shared_examples 'invokes OnelinerShould#expectize! if available' do
        context 'and RSpecVersion#oneliner_is_expected_available? returns true' do
          before { rspec_version.stub(:oneliner_is_expected_available?).and_return(true) }

          it 'invokes OnelinerShould#expectize!' do
            should_object.should_receive(:expectize!)
            converter.process_oneliner_should(should_object)
          end
        end

        context 'and RSpecVersion#oneliner_is_expected_available? returns false' do
          before { rspec_version.stub(:oneliner_is_expected_available?).and_return(false) }
          include_examples 'does nothing'
        end
      end

      shared_examples 'converts to standard expecatations' do
        context 'and Config#convert_should? is true' do
          before { config.convert_should = true }

          it 'invokes OnelinerShould#convert_have_items_to_standard_expect!' do
            should_object.should_receive(:convert_have_items_to_standard_expect!)
            converter.process_oneliner_should(should_object)
          end
        end

        context 'and Config#convert_should? is false' do
          before { config.convert_should = false }

          it 'invokes OnelinerShould#convert_have_items_to_standard_should!' do
            should_object.should_receive(:convert_have_items_to_standard_should!)
            converter.process_oneliner_should(should_object)
          end
        end
      end

      context 'when Config#convert_oneliner? is true' do
        before { config.convert_oneliner = true }

        context 'and the #have matcher is conversion target' do
          before do
            have_object.stub(:conversion_target?).and_return(true)
          end

          context 'and Config#convert_have_items? is true' do
            before { config.convert_have_items = true }
            include_examples 'converts to standard expecatations'
          end

          context 'and Config#convert_have_items? is false' do
            before { config.convert_have_items = false }
            include_examples 'invokes OnelinerShould#expectize! if available'
          end
        end

        context 'and the #have matcher is not conversion target' do
          before do
            have_object.stub(:conversion_target?).and_return(false)
          end

          context 'and Config#convert_have_items? is true' do
            before { config.convert_have_items = true }
            include_examples 'invokes OnelinerShould#expectize! if available'
          end

          context 'and Config#convert_have_items? is false' do
            before { config.convert_have_items = false }
            include_examples 'invokes OnelinerShould#expectize! if available'
          end
        end
      end

      context 'when Config#convert_oneliner? is false' do
        before { config.convert_oneliner = false }

        context 'and the #have matcher is conversion target' do
          before do
            have_object.stub(:conversion_target?).and_return(true)
          end

          context 'and Config#convert_have_items? is true' do
            before { config.convert_have_items = true }
            include_examples 'converts to standard expecatations'
          end

          context 'and Config#convert_have_items? is false' do
            before { config.convert_have_items = false }
            include_examples 'does nothing'
          end
        end

        context 'and the #have matcher is not conversion target' do
          before do
            have_object.stub(:conversion_target?).and_return(false)
          end

          context 'and Config#convert_have_items? is true' do
            before { config.convert_have_items = true }
            include_examples 'does nothing'
          end

          context 'and Config#convert_have_items? is false' do
            before { config.convert_have_items = false }
            include_examples 'does nothing'
          end
        end
      end
    end

    describe '#process_should_receive' do
      let(:should_receive_object) { double('should_receive_object').as_null_object }

      shared_examples 'does nothing' do
        it 'does nothing' do
          should_receive_object.should_not_receive(:expectize!)
          should_receive_object.should_not_receive(:allowize_any_number_of_times!)
          should_receive_object.should_not_receive(:stubize_any_number_of_times!)
          converter.process_should_receive(should_receive_object)
        end
      end

      context 'when ShouldReceive#useless_expectation? returns true' do
        before { should_receive_object.stub(:useless_expectation?).and_return(true) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          context 'and Config#convert_stub? is true' do
            before { config.convert_stub = true }

            [true, false].each do |convert_should_receive|
              context "and Config#convert_should_receive? is #{convert_should_receive}" do
                before { config.convert_should_receive = convert_should_receive }

                context 'and Config#negative_form_of_to is "not_to"' do
                  before { config.negative_form_of_to = 'not_to' }

                  it 'invokes ShouldReceive#allowize_useless_expectation! with "not_to"' do
                    should_receive_object.should_receive(:allowize_useless_expectation!).with('not_to')
                    converter.process_should_receive(should_receive_object)
                  end
                end

                context 'and Config#negative_form_of_to is "to_not"' do
                  before { config.negative_form_of_to = 'to_not' }

                  it 'invokes ShouldReceive#allowize_useless_expectation! with "to_not"' do
                    should_receive_object.should_receive(:allowize_useless_expectation!).with('to_not')
                    converter.process_should_receive(should_receive_object)
                  end
                end
              end
            end
          end

          context 'and Config#convert_stub? is false' do
            before { config.convert_stub = false }

            [true, false].each do |convert_should_receive|
              context "and Config#convert_should_receive? is #{convert_should_receive}" do
                before { config.convert_should_receive = convert_should_receive }

                it 'invokes ShouldReceive#stubize_useless_expectation!' do
                  should_receive_object.should_receive(:stubize_useless_expectation!)
                  converter.process_should_receive(should_receive_object)
                end
              end
            end
          end
        end

        context 'and Config#convert_deprecated_method? is false' do
          before { config.convert_deprecated_method = false }

          [true, false].each do |convert_stub|
            context "and Config#convert_stub? is #{convert_stub}" do
              before { config.convert_stub = convert_stub }

              context 'and Config#convert_should_receive? is true' do
                before { config.convert_should_receive = true }

                context 'and Config#negative_form_of_to is "not_to"' do
                  before { config.negative_form_of_to = 'not_to' }

                  it 'invokes ShouldReceive#expectize! with "not_to"' do
                    should_receive_object.should_receive(:expectize!).with('not_to')
                    converter.process_should_receive(should_receive_object)
                  end
                end

                context 'and Config#negative_form_of_to is "to_not"' do
                  before { config.negative_form_of_to = 'to_not' }

                  it 'invokes ShouldReceive#expectize! with "to_not"' do
                    should_receive_object.should_receive(:expectize!).with('to_not')
                    converter.process_should_receive(should_receive_object)
                  end
                end
              end

              context 'and Config#convert_should_receive? is false' do
                before { config.convert_should_receive = false }

                include_examples 'does nothing'
              end
            end
          end
        end
      end

      context 'when ShouldReceive#useless_expectation? returns false' do
        before { should_receive_object.stub(:useless_expectation?).and_return(false) }

        context 'and Config#convert_should_receive? is true' do
          before { config.convert_should_receive = true }

          [true, false].each do |convert_deprecated_method|
            context "and Config#convert_deprecated_method? is #{convert_deprecated_method}" do
              before { config.convert_deprecated_method = convert_deprecated_method }

              [true, false].each do |convert_stub|
                context "and Config#convert_stub? is #{convert_stub}" do
                  before { config.convert_stub = convert_stub }

                  context 'and Config#negative_form_of_to is "not_to"' do
                    before { config.negative_form_of_to = 'not_to' }

                    it 'invokes ShouldReceive#expectize! with "not_to"' do
                      should_receive_object.should_receive(:expectize!).with('not_to')
                      converter.process_should_receive(should_receive_object)
                    end
                  end

                  context 'and Config#negative_form_of_to is "to_not"' do
                    before { config.negative_form_of_to = 'to_not' }

                    it 'invokes ShouldReceive#expectize! with "to_not"' do
                      should_receive_object.should_receive(:expectize!).with('to_not')
                      converter.process_should_receive(should_receive_object)
                    end
                  end
                end
              end
            end
          end
        end

        context 'and Config#convert_should_receive? is false' do
          before { config.convert_should_receive = false }

          [true, false].each do |convert_deprecated_method|
            context "and Config#convert_deprecated_method? is #{convert_deprecated_method}" do
              before { config.convert_deprecated_method = convert_deprecated_method }

              [true, false].each do |convert_stub|
                context "and Config#convert_stub? is #{convert_stub}" do
                  before { config.convert_stub = convert_stub }

                  include_examples 'does nothing'
                end
              end
            end
          end
        end
      end
    end

    describe '#process_method_stub' do
      let(:method_stub_object) { double('method_stub_object').as_null_object }

      shared_examples 'invokes MethodStub#allowize!' do
        it 'invokes MethodStub#allowize! with RSpecVersion' do
          method_stub_object.should_receive(:allowize!).with(rspec_version)
          converter.process_method_stub(method_stub_object)
        end
      end

      shared_examples 'does not invoke MethodStub#allowize!' do
        it 'does not invoke MethodStub#allowize!' do
          method_stub_object.should_not_receive(:allowize!)
          converter.process_method_stub(method_stub_object)
        end
      end

      shared_examples 'invokes MethodStub#convert_deprecated_method!' do
        it 'invokes MethodStub#convert_deprecated_method!' do
          method_stub_object.should_receive(:convert_deprecated_method!)
          converter.process_method_stub(method_stub_object)
        end
      end

      shared_examples 'does not invoke MethodStub#convert_deprecated_method!' do
        it 'does not invoke MethodStub#convert_deprecated_method!' do
          method_stub_object.should_not_receive(:convert_deprecated_method!)
          converter.process_method_stub(method_stub_object)
        end
      end

      shared_examples 'invokes MethodStub#remove_no_message_allowance!' do
        it 'invokes MethodStub#remove_no_message_allowance!' do
          method_stub_object.should_receive(:remove_no_message_allowance!)
          converter.process_method_stub(method_stub_object)
        end
      end

      shared_examples 'does not invoke MethodStub#remove_no_message_allowance!' do
        it 'does not invoke MethodStub#remove_no_message_allowance!' do
          method_stub_object.should_not_receive(:remove_no_message_allowance!)
          converter.process_method_stub(method_stub_object)
        end
      end

      context 'when Config#convert_stub? is true' do
        before { config.convert_stub = true }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          context 'and MethodStub#hash_arg? is false' do
            before { method_stub_object.stub(:hash_arg?).and_return(false) }
            include_examples 'invokes MethodStub#allowize!'
            include_examples 'does not invoke MethodStub#convert_deprecated_method!'
            include_examples 'invokes MethodStub#remove_no_message_allowance!'
          end

          context 'and MethodStub#hash_arg? is true' do
            before { method_stub_object.stub(:hash_arg?).and_return(true) }

            context 'and Config#convert_stub_with_hash_to_allow_to_receive_and_return? is true' do
              before { config.convert_stub_with_hash_to_allow_to_receive_and_return = true }

              context 'and RSpecVersion#receive_messages_available? is true' do
                before { rspec_version.stub(:receive_messages_available?).and_return(true) }
                include_examples 'invokes MethodStub#allowize!'
                include_examples 'does not invoke MethodStub#convert_deprecated_method!'
                include_examples 'invokes MethodStub#remove_no_message_allowance!'
              end

              context 'and RSpecVersion#receive_messages_available? is false' do
                before { rspec_version.stub(:receive_messages_available?).and_return(false) }
                include_examples 'invokes MethodStub#allowize!'
                include_examples 'does not invoke MethodStub#convert_deprecated_method!'
                include_examples 'invokes MethodStub#remove_no_message_allowance!'
              end
            end

            context 'and Config#convert_stub_with_hash_to_allow_to_receive_and_return? is false' do
              before { config.convert_stub_with_hash_to_allow_to_receive_and_return = false }

              context 'and RSpecVersion#receive_messages_available? is true' do
                before { rspec_version.stub(:receive_messages_available?).and_return(true) }
                include_examples 'invokes MethodStub#allowize!'
                include_examples 'does not invoke MethodStub#convert_deprecated_method!'
                include_examples 'invokes MethodStub#remove_no_message_allowance!'
              end

              context 'and RSpecVersion#receive_messages_available? is false' do
                before { rspec_version.stub(:receive_messages_available?).and_return(false) }
                include_examples 'does not invoke MethodStub#allowize!'
                include_examples 'invokes MethodStub#convert_deprecated_method!'
                include_examples 'invokes MethodStub#remove_no_message_allowance!'
              end
            end
          end
        end

        context 'and Config#convert_deprecated_method? is false' do
          before do
            config.convert_deprecated_method = false
            method_stub_object.stub(:hash_arg?).and_return(false)
          end

          include_examples 'invokes MethodStub#allowize!'
          include_examples 'does not invoke MethodStub#convert_deprecated_method!'
          include_examples 'does not invoke MethodStub#remove_no_message_allowance!'
        end
      end

      context 'when Config#convert_stub? is false' do
        before { config.convert_stub = false }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          include_examples 'does not invoke MethodStub#allowize!'
          include_examples 'invokes MethodStub#convert_deprecated_method!'
          include_examples 'invokes MethodStub#remove_no_message_allowance!'
        end

        context 'and Config#convert_deprecated_method? is false' do
          before { config.convert_deprecated_method = false }

          include_examples 'does not invoke MethodStub#allowize!'
          include_examples 'does not invoke MethodStub#convert_deprecated_method!'
          include_examples 'does not invoke MethodStub#remove_no_message_allowance!'
        end
      end
    end

    describe '#process_double' do
      let(:double_object) { double('double_object').as_null_object }

      context 'when Config#convert_deprecated_method? is true' do
        before { config.convert_deprecated_method = true }

        it 'invokes Double#convert_to_double!' do
          double_object.should_receive(:convert_to_double!)
          converter.process_double(double_object)
        end
      end

      context 'when Config#convert_deprecated_method? is false' do
        before { config.convert_deprecated_method = false }

        it 'does nothing' do
          double_object.should_not_receive(:convert_to_double!)
          converter.process_double(double_object)
        end
      end
    end

    describe '#process_operator' do
      let(:operator_object) { double('operator_object').as_null_object }

      context 'when Config#convert_should? is true' do
        before { config.convert_should = true }

        context 'and Config#parenthesize_matcher_arg is true' do
          before { config.parenthesize_matcher_arg = true }

          it 'invokes Operator#convert_operator! with true' do
            operator_object.should_receive(:convert_operator!).with(true)
            converter.process_operator(operator_object)
          end
        end

        context 'and Config#parenthesize_matcher_arg is false' do
          before { config.parenthesize_matcher_arg = false }

          it 'invokes Should#expectize! with false as second argument' do
            operator_object.should_receive(:convert_operator!).with(false)
            converter.process_operator(operator_object)
          end
        end

        context 'and the expectation is one-liner should' do
          before do
            operator_object.stub(:expectation).and_return(Syntax::OnelinerShould.new(nil))
          end

          context 'and RSpecVersion#oneliner_is_expected_available? returns true' do
            before { rspec_version.stub(:oneliner_is_expected_available?).and_return(true) }

            it 'invokes Operator#convert_operator!' do
              operator_object.should_receive(:convert_operator!)
              converter.process_operator(operator_object)
            end
          end

          context 'and RSpecVersion#oneliner_is_expected_available? returns false' do
            before { rspec_version.stub(:oneliner_is_expected_available?).and_return(false) }

            it 'does not invoke Operator#convert_operator!' do
              operator_object.should_not_receive(:convert_operator!)
              converter.process_operator(operator_object)
            end
          end
        end
      end

      context 'when Config#convert_should? is false' do
        before { config.convert_should = false }

        it 'does not invoke Operator#convert_operator!' do
          operator_object.should_not_receive(:convert_operator!)
          converter.process_operator(operator_object)
        end
      end
    end

    describe '#process_be_boolean' do
      let(:be_boolean_object) { double('be_boolean_object').as_null_object }

      context 'when RSpecVersion#be_truthy_available? returns true' do
        before { rspec_version.stub(:be_truthy_available?).and_return(true) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          context 'and Config#boolean_matcher_type is :conditional' do
            before { config.boolean_matcher_type = :conditional }

            context 'and Config#form_of_be_falsey is "be_falsey"' do
              before { config.form_of_be_falsey = 'be_falsey' }

              it 'invokes BeBoolean#convert_to_conditional_matcher! with "be_falsey"' do
                be_boolean_object.should_receive(:convert_to_conditional_matcher!).with('be_falsey')
                converter.process_be_boolean(be_boolean_object)
              end
            end

            context 'and Config#form_of_be_falsey is "be_falsy"' do
              before { config.form_of_be_falsey = 'be_falsy' }

              it 'invokes BeBoolean#convert_to_conditional_matcher! with "be_falsy"' do
                be_boolean_object.should_receive(:convert_to_conditional_matcher!).with('be_falsy')
                converter.process_be_boolean(be_boolean_object)
              end
            end
          end

          context 'and Config#boolean_matcher_type is :exact' do
            before { config.boolean_matcher_type = :exact }

            it 'invokes BeBoolean#convert_to_exact_matcher!' do
              be_boolean_object.should_receive(:convert_to_exact_matcher!)
              converter.process_be_boolean(be_boolean_object)
            end
          end
        end

        context 'and Config#convert_deprecated_method? is false' do
          before { config.convert_deprecated_method = false }

          it 'does nothing' do
            be_boolean_object.should_not_receive(:convert_to_conditional_matcher!)
            be_boolean_object.should_not_receive(:convert_to_exact_matcher!)
            converter.process_be_boolean(be_boolean_object)
          end
        end
      end

      context 'when RSpecVersion#be_truthy_available? returns true' do
        before { rspec_version.stub(:be_truthy_available?).and_return(false) }

        it 'does nothing' do
          be_boolean_object.should_not_receive(:convert_to_conditional_matcher!)
          be_boolean_object.should_not_receive(:convert_to_exact_matcher!)
          converter.process_be_boolean(be_boolean_object)
        end
      end
    end

    describe '#process_be_close' do
      let(:be_close_object) { double('be_close_object').as_null_object }

      context 'when Config#convert_deprecated_method? is true' do
        before { config.convert_deprecated_method = true }

        it 'invokes BeClose#convert_to_be_within!' do
          be_close_object.should_receive(:convert_to_be_within!)
          converter.process_be_close(be_close_object)
        end
      end

      context 'when Config#convert_deprecated_method? is false' do
        before { config.convert_deprecated_method = false }

        it 'does nothing' do
          be_close_object.should_not_receive(:convert_to_be_within!)
          converter.process_be_close(be_close_object)
        end
      end
    end

    describe '#process_have' do
      let(:have_object) { double('have_object').as_null_object }

      context 'when Config#convert_have_items? is true' do
        before { config.convert_have_items = true }

        context 'and Config#parenthesize_matcher_arg is true' do
          before { config.parenthesize_matcher_arg = true }

          it 'invokes Have#convert_to_standard_expectation! with true' do
            have_object.should_receive(:convert_to_standard_expectation!).with(true)
            converter.process_have(have_object)
          end
        end

        context 'and Config#parenthesize_matcher_arg is false' do
          before { config.parenthesize_matcher_arg = false }

          it 'invokes Have#convert_to_standard_expectation! with false' do
            have_object.should_receive(:convert_to_standard_expectation!).with(false)
            converter.process_have(have_object)
          end
        end
      end

      context 'when Config#convert_have_items? is false' do
        before { config.convert_have_items = false }

        it 'does not invoke Have#convert_to_standard_expectation!' do
          have_object.should_not_receive(:convert_to_standard_expectation!)
          converter.process_have(have_object)
        end
      end
    end

    describe '#process_hook' do
      let(:hook_object) { double('hook_object').as_null_object }

      context 'when Config#convert_hook_scope? is true' do
        before { config.convert_hook_scope = true }

        context 'when RSpecVersion#hook_scope_alias_available? returns true' do
          before { rspec_version.stub(:hook_scope_alias_available?).and_return(true) }

          it 'invokes Hook#convert_scope_name!' do
            hook_object.should_receive(:convert_scope_name!)
            converter.process_hook(hook_object)
          end
        end

        context 'when RSpecVersion#hook_scope_alias_available? returns false' do
          before { rspec_version.stub(:hook_scope_alias_available?).and_return(false) }

          it 'does nothing' do
            hook_object.should_not_receive(:convert_scope_name!)
            converter.process_hook(hook_object)
          end
        end
      end

      context 'when Config#convert_hook_scope? is false' do
        before { config.convert_hook_scope = false }

        context 'when RSpecVersion#hook_scope_alias_available? returns true' do
          before { rspec_version.stub(:hook_scope_alias_available?).and_return(true) }

          it 'does nothing' do
            hook_object.should_not_receive(:convert_scope_name!)
            converter.process_hook(hook_object)
          end
        end
      end
    end

    describe '#process_raise_error' do
      let(:raise_error_object) { double('raise_error_object').as_null_object }

      context 'when Config#convert_deprecated_method? is true' do
        before { config.convert_deprecated_method = true }

        it 'invokes RaiseError#remove_error_specification_with_negative_expectation!' do
          raise_error_object.should_receive(:remove_error_specification_with_negative_expectation!)
          converter.process_raise_error(raise_error_object)
        end
      end

      context 'when Config#convert_deprecated_method? is false' do
        before { config.convert_deprecated_method = false }

        it 'does nothing' do
          raise_error_object.should_not_receive(:remove_error_specification_with_negative_expectation!)
          converter.process_raise_error(raise_error_object)
        end
      end
    end

    describe '#process_its' do
      let(:its_object) { double('its_object').as_null_object }

      context 'when Config#convert_its? is true' do
        before { config.convert_its = true }

        it 'invokes Its#convert_to_describe_subject_it!' do
          its_object.should_receive(:convert_to_describe_subject_it!)
          converter.process_its(its_object)
        end
      end

      context 'when Config#convert_its? is false' do
        before { config.convert_its = false }

        it 'does nothing' do
          its_object.should_not_receive(:convert_to_describe_subject_it!)
          converter.process_its(its_object)
        end
      end
    end

    describe '#process_example' do
      let(:example_object) { double('example_object').as_null_object }

      shared_examples 'does nothing' do
        it 'does nothing' do
          example_object.should_not_receive(:convert_pending_to_skip!)
          converter.process_example(example_object)
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns true' do
        before { rspec_version.stub(:rspec_2_99?).and_return(true) }

        context 'and Config#convert_pending? returns true' do
          before { config.convert_pending = true }

          it 'invokes Example#convert_pending_to_skip!' do
            example_object.should_receive(:convert_pending_to_skip!)
            converter.process_example(example_object)
          end
        end

        context 'and Config#convert_pending? returns false' do
          before { config.convert_pending = false }
          include_examples 'does nothing'
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns false' do
        before { rspec_version.stub(:rspec_2_99?).and_return(false) }

        context 'and Config#convert_pending? returns true' do
          before { config.convert_pending = true }
          include_examples 'does nothing'
        end

        context 'and Config#convert_pending? returns false' do
          before { config.convert_pending = false }
          include_examples 'does nothing'
        end
      end
    end

    describe '#process_pending' do
      let(:pending_object) { double('pending_object').as_null_object }

      shared_examples 'does nothing' do
        it 'does nothing' do
          pending_object.should_not_receive(:convert_deprecated_syntax!)
          converter.process_pending(pending_object)
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns true' do
        before { rspec_version.stub(:rspec_2_99?).and_return(true) }

        context 'and Config#convert_pending? returns true' do
          before { config.convert_pending = true }

          it 'invokes Example#convert_deprecated_syntax!' do
            pending_object.should_receive(:convert_deprecated_syntax!)
            converter.process_pending(pending_object)
          end
        end

        context 'and Config#convert_pending? returns false' do
          before { config.convert_pending = false }
          include_examples 'does nothing'
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns false' do
        before { rspec_version.stub(:rspec_2_99?).and_return(false) }

        context 'and Config#convert_pending? returns true' do
          before { config.convert_pending = true }
          include_examples 'does nothing'
        end

        context 'and Config#convert_pending? returns false' do
          before { config.convert_pending = false }
          include_examples 'does nothing'
        end
      end
    end

    describe '#process_current_example' do
      let(:current_example_object) { double('current_example_object').as_null_object }

      context 'when RSpecVersion#yielded_example_available? returns true' do
        before { rspec_version.stub(:yielded_example_available?).and_return(true) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          it 'invokes CurrentExample#convert!' do
            current_example_object.should_receive(:convert!)
            converter.process_current_example(current_example_object)
          end
        end

        context 'and Config#convert_deprecated_method? is false' do
          before { config.convert_deprecated_method = false }

          it 'does nothing' do
            current_example_object.should_not_receive(:convert!)
            converter.process_current_example(current_example_object)
          end
        end
      end

      context 'when RSpecVersion#yielded_example_available? returns false' do
        before { rspec_version.stub(:yielded_example_available?).and_return(false) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          it 'does nothing' do
            current_example_object.should_not_receive(:convert!)
            converter.process_current_example(current_example_object)
          end
        end
      end
    end

    describe '#process_matcher_definition' do
      let(:matcher_definition) { double('matcher_definition').as_null_object }

      context 'when RSpecVersion#non_should_matcher_protocol_available? returns true' do
        before { rspec_version.stub(:non_should_matcher_protocol_available?).and_return(true) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          it 'invokes MatcherDefinition#convert_deprecated_method!' do
            matcher_definition.should_receive(:convert_deprecated_method!)
            converter.process_matcher_definition(matcher_definition)
          end
        end

        context 'and Config#convert_deprecated_method? is false' do
          before { config.convert_deprecated_method = false }

          it 'does nothing' do
            matcher_definition.should_not_receive(:convert_deprecated_method!)
            converter.process_matcher_definition(matcher_definition)
          end
        end
      end

      context 'when RSpecVersion#non_should_matcher_protocol_available? returns false' do
        before { rspec_version.stub(:non_should_matcher_protocol_available?).and_return(false) }

        context 'and Config#convert_deprecated_method? is true' do
          before { config.convert_deprecated_method = true }

          it 'does nothing' do
            matcher_definition.should_not_receive(:convert_deprecated_method!)
            converter.process_matcher_definition(matcher_definition)
          end
        end
      end
    end

    describe '#process_example_group' do
      let(:example_group) { double('example_group').as_null_object }

      context 'when RSpecVersion#non_monkey_patch_example_group_available? returns true' do
        before { rspec_version.stub(:non_monkey_patch_example_group_available?).and_return(true) }

        context 'and Config#convert_example_group? is true' do
          before { config.convert_example_group = true }

          it 'invokes ExampleGroup#convert_to_non_monkey_patch!' do
            example_group.should_receive(:convert_to_non_monkey_patch!)
            converter.process_example_group(example_group)
          end
        end

        context 'and Config#convert_example_group? is false' do
          before { config.convert_example_group = false }

          it 'does nothing' do
            example_group.should_not_receive(:convert_to_non_monkey_patch!)
            converter.process_example_group(example_group)
          end
        end
      end

      context 'when RSpecVersion#non_monkey_patch_example_group_available? returns false' do
        before { rspec_version.stub(:non_monkey_patch_example_group_available?).and_return(false) }

        context 'and Config#convert_example_group? is true' do
          before { config.convert_example_group = true }

          it 'does nothing' do
            example_group.should_not_receive(:convert_to_non_monkey_patch!)
            converter.process_example_group(example_group)
          end
        end
      end

      context 'when RSpecVersion#implicit_spec_type_disablement_available? returns true' do
        before { rspec_version.stub(:implicit_spec_type_disablement_available?).and_return(true) }

        context 'and Config#add_explicit_type_metadata_to_example_group? is true' do
          before { config.add_explicit_type_metadata_to_example_group = true }

          it 'invokes ExampleGroup#add_explicit_type_metadata!' do
            example_group.should_receive(:add_explicit_type_metadata!)
            converter.process_example_group(example_group)
          end
        end

        context 'and Config#add_explicit_type_metadata_to_example_group? is false' do
          before { config.add_explicit_type_metadata_to_example_group = false }

          it 'does nothing' do
            example_group.should_not_receive(:add_explicit_type_metadata!)
            converter.process_example_group(example_group)
          end
        end
      end

      context 'when RSpecVersion#implicit_spec_type_disablement_available? returns false' do
        before { rspec_version.stub(:implicit_spec_type_disablement_available?).and_return(false) }

        context 'and Config#add_explicit_type_metadata_to_example_group? is true' do
          before { config.add_explicit_type_metadata_to_example_group = true }

          it 'does nothing' do
            example_group.should_not_receive(:add_explicit_type_metadata!)
            converter.process_example_group(example_group)
          end
        end
      end
    end

    describe '#process_rspec_configure' do
      let(:rspec_configure) do
        double(
          'rspec_configure',
          expectations: double('expectations').as_null_object,
                 mocks: double('mocks').as_null_object
        ).as_null_object
      end

      context 'when Config#convert_deprecated_method? returns true' do
        before { config.convert_deprecated_method = true }

        it 'invokes RSpecConfigure#convert_deprecated_options! with RSpecVersion' do
          rspec_configure.should_receive(:convert_deprecated_options!).with(rspec_version)
          converter.process_rspec_configure(rspec_configure)
        end
      end

      context 'when Config#convert_deprecated_method? returns false' do
        before { config.convert_deprecated_method = false }

        it 'does not invoke RSpecConfigure#convert_deprecated_options!' do
          rspec_configure.should_not_receive(:convert_deprecated_options!)
          converter.process_rspec_configure(rspec_configure)
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns true' do
        before do
          rspec_version.stub(:rspec_2_99?).and_return(true)
        end

        context 'and Config#convert_deprecated_method? returns true' do
          before { config.convert_deprecated_method = true }

          context 'and SpecSuite#main_rspec_configure_node? returns true' do
            before do
              spec_suite.stub(:main_rspec_configure_node?).and_return(true)
            end

            context 'and SpecSuite#need_to_modify_yield_receiver_..._config? return true' do
              before do
                spec_suite.stub(:need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config?)
                  .and_return(true)
              end

              context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns true' do
                before { config.add_receiver_arg_to_any_instance_implementation_block = true }

                it 'invokes RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks= with true' do
                  rspec_configure.mocks
                    .should_receive(:yield_receiver_to_any_instance_implementation_blocks=).with(true)
                  converter.process_rspec_configure(rspec_configure)
                end
              end

              context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns false' do
                before { config.add_receiver_arg_to_any_instance_implementation_block = false }

                it 'invokes RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks= with false' do
                  rspec_configure.mocks
                    .should_receive(:yield_receiver_to_any_instance_implementation_blocks=).with(false)
                  converter.process_rspec_configure(rspec_configure)
                end
              end
            end
          end

          context 'and SpecSuite#need_to_modify_yield_receiver_..._config? return false' do
            before do
              spec_suite.stub(:need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config?)
                .and_return(false)
            end

            context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns true' do
              before { config.add_receiver_arg_to_any_instance_implementation_block = true }

              it 'does not invoke RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks=' do
                rspec_configure.mocks.should_not_receive(:yield_receiver_to_any_instance_implementation_blocks=)
                converter.process_rspec_configure(rspec_configure)
              end
            end
          end

          context 'and SpecSuite#main_rspec_configure_node? returns false' do
            before do
              spec_suite.stub(:main_rspec_configure_node?).and_return(false)
            end

            context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns true' do
              before { config.add_receiver_arg_to_any_instance_implementation_block = true }

              it 'does not invoke RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks=' do
                rspec_configure.mocks.should_not_receive(:yield_receiver_to_any_instance_implementation_blocks=)
                converter.process_rspec_configure(rspec_configure)
              end
            end
          end
        end

        context 'and Config#convert_deprecated_method? returns false' do
          before { config.convert_deprecated_method = false }

          it 'does not invoke RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks=' do
            rspec_configure.mocks.should_not_receive(:yield_receiver_to_any_instance_implementation_blocks=)
            converter.process_rspec_configure(rspec_configure)
          end
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns false' do
        before do
          rspec_version.stub(:rspec_2_99?).and_return(false)
        end

        it 'does not invoke RSpecConfigure.mocks.yield_receiver_to_any_instance_implementation_blocks=' do
          rspec_configure.mocks.should_not_receive(:yield_receiver_to_any_instance_implementation_blocks=)
          converter.process_rspec_configure(rspec_configure)
        end
      end

      context 'when RSpecVersion#non_monkey_patch_example_group_available? returns true' do
        before { rspec_version.stub(:non_monkey_patch_example_group_available?).and_return(true) }

        context 'and Config#convert_example_group? is true' do
          before { config.convert_example_group = true }

          it 'invokes RSpecConfigure#expose_dsl_globally= with false' do
            rspec_configure.should_receive(:expose_dsl_globally=).with(false)
            converter.process_rspec_configure(rspec_configure)
          end
        end

        context 'and Config#convert_example_group? is false' do
          before { config.convert_example_group = false }

          it 'does nothing' do
            rspec_configure.should_not_receive(:expose_dsl_globally=)
            converter.process_rspec_configure(rspec_configure)
          end
        end
      end

      context 'when RSpecVersion#non_monkey_patch_example_group_available? returns false' do
        before { rspec_version.stub(:non_monkey_patch_example_group_available?).and_return(false) }

        context 'and Config#convert_example_group? is true' do
          before { config.convert_example_group = true }

          it 'does nothing' do
            rspec_configure.should_not_receive(:expose_dsl_globally=)
            converter.process_rspec_configure(rspec_configure)
          end
        end
      end
    end

    describe '#process_useless_and_return' do
      let(:messaging_host) { double('messaging host').as_null_object }

      context 'when Config#convert_deprecated_method? returns true' do
        before { config.convert_deprecated_method = true }

        it 'invokes #remove_useless_and_return!' do
          messaging_host.should_receive(:remove_useless_and_return!)
          converter.process_useless_and_return(messaging_host)
        end
      end

      context 'when Config#convert_deprecated_method? returns false' do
        before { config.convert_deprecated_method = false }

        it 'does nothing' do
          messaging_host.should_not_receive(:remove_useless_and_return!)
          converter.process_useless_and_return(messaging_host)
        end
      end
    end

    describe '#process_any_instance_block' do
      let(:messaging_host) { double('messaging host').as_null_object }

      context 'when RSpecVersion#rspec_2_99? returns true' do
        before do
          rspec_version.stub(:rspec_2_99?).and_return(true)
        end

        context 'and Config#convert_deprecated_method? returns true' do
          before { config.convert_deprecated_method = true }

          context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns true' do
            before { config.add_receiver_arg_to_any_instance_implementation_block = true }

            it 'invokes #add_receiver_arg_to_any_instance_implementation_block!' do
              messaging_host.should_receive(:add_receiver_arg_to_any_instance_implementation_block!)
              converter.process_any_instance_block(messaging_host)
            end
          end

          context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns false' do
            before { config.add_receiver_arg_to_any_instance_implementation_block = false }

            it 'does nothing' do
              messaging_host.should_not_receive(:add_instance_arg_to_any_instance_implementation_block!)
              converter.process_any_instance_block(messaging_host)
            end
          end
        end

        context 'and Config#convert_deprecated_method? returns false' do
          before { config.convert_deprecated_method = false }

          context 'and Config#add_receiver_arg_to_any_instance_implementation_block? returns true' do
            before { config.add_receiver_arg_to_any_instance_implementation_block = true }

            it 'does nothing' do
              messaging_host.should_not_receive(:add_instance_arg_to_any_instance_implementation_block!)
              converter.process_any_instance_block(messaging_host)
            end
          end
        end
      end

      context 'when RSpecVersion#rspec_2_99? returns false' do
        before do
          rspec_version.stub(:rspec_2_99?).and_return(false)
        end

        it 'does nothing' do
          messaging_host.should_not_receive(:add_instance_arg_to_any_instance_implementation_block!)
          converter.process_any_instance_block(messaging_host)
        end
      end
    end
  end
end
