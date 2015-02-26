# coding: utf-8

require 'spec_helper'
require 'transpec/option_parser'

module Transpec
  describe OptionParser do
    subject(:parser) { OptionParser.new(config) }
    let(:config) { Config.new }

    describe '#parse' do
      subject { parser.parse(args) }
      let(:args) { ['some_file', '--negative-form', 'to_not', 'some_dir'] }

      it 'return non-option arguments' do
        should == ['some_file', 'some_dir']
      end

      it 'does not mutate the passed array' do
        parser.parse(args)
        args.should == ['some_file', '--negative-form', 'to_not', 'some_dir']
      end

      describe '-f/--force option' do
        let(:args) { ['--force'] }

        it 'sets Config#forced? true' do
          parser.parse(args)
          config.forced?.should be_true
        end
      end

      describe '-s/--skip-dynamic-analysis option' do
        let(:args) { ['--skip-dynamic-analysis'] }

        it 'sets Config#skip_dynamic_analysis? true' do
          parser.parse(args)
          config.skip_dynamic_analysis?.should be_true
        end
      end

      describe '-k/--keep option' do
        [
          'should',
          'oneliner',
          'should_receive',
          'stub',
          'have_items',
          'its',
          'pending',
          'deprecated'
        ].each do |type|
          context "when #{type.inspect} is specified" do
            let(:args) { ['--keep', type] }

            it "sets Config#convert? with :#{type} false" do
              parser.parse(args)
              config.convert?(type).should be_false
            end
          end
        end

        context 'when multiple types are specified with comma' do
          let(:args) { ['--keep', 'should_receive,deprecated'] }

          it 'handles all of them' do
            parser.parse(args)
            config.convert?(:should_receive).should be_false
            config.convert?(:deprecated).should be_false
          end
        end

        context 'when unknown type is specified' do
          let(:args) { ['--keep', 'unknown'] }

          it 'raises error' do
            -> { parser.parse(args) }.should raise_error(ArgumentError) { |error|
              error.message.should == 'Unknown syntax type "unknown"'
            }
          end
        end
      end

      describe '-v/--convert option' do
        [
          'example_group',
          'hook_scope',
          'stub_with_hash'
        ].each do |type|
          context "when #{type.inspect} is specified" do
            let(:args) { ['--convert', type] }

            it "sets Config#convert? with :#{type} true" do
              parser.parse(args)
              config.convert?(type).should be_true
            end
          end
        end

        context 'when unknown type is specified' do
          let(:args) { ['--convert', 'unknown'] }

          it 'raises error' do
            -> { parser.parse(args) }.should raise_error(ArgumentError) { |error|
              error.message.should == 'Unknown syntax type "unknown"'
            }
          end
        end
      end

      describe '-n/--negative-form option' do
        ['not_to', 'to_not'].each do |form|
          context "when #{form.inspect} is specified" do
            let(:args) { ['--negative-form', form] }

            it "sets Config#negative_form_of_to #{form.inspect}" do
              parser.parse(args)
              config.negative_form_of_to.should == form
            end
          end
        end
      end

      describe '-b/--boolean-matcher option' do
        [
          ['truthy,falsey', :conditional, 'be_falsey'],
          ['truthy,falsy',  :conditional, 'be_falsy'],
          ['true,false',    :exact,       'be_falsey']
        ].each do |cli_type, config_type, form_of_be_falsey|
          context "when #{cli_type.inspect} is specified" do
            let(:args) { ['--boolean-matcher', cli_type] }

            it "sets Config#boolean_matcher_type #{config_type.inspect}" do
              parser.parse(args)
              config.boolean_matcher_type.should == config_type
            end

            it "sets Config#form_of_be_falsey #{form_of_be_falsey.inspect}" do
              parser.parse(args)
              config.form_of_be_falsey.should == form_of_be_falsey
            end
          end
        end

        ['', 'truthy', 'true', 'foo'].each do |cli_type|
          context "when #{cli_type.inspect} is specified" do
            let(:args) { ['--boolean-matcher', cli_type] }

            it 'raises error' do
              -> { parser.parse(args) }.should raise_error(/must be any of/)
            end
          end
        end
      end

      describe '-a/--no-yield-any-instance option' do
        let(:args) { ['--no-yield-any-instance'] }

        it 'sets Config#add_receiver_arg_to_any_instance_implementation_block? false' do
          parser.parse(args)
          config.add_receiver_arg_to_any_instance_implementation_block?
            .should be_false
        end
      end

      describe '-e/--explicit-spec-type option' do
        let(:args) { ['--explicit-spec-type'] }

        it 'sets Config#add_explicit_type_metadata_to_example_group? true' do
          parser.parse(args)
          config.add_explicit_type_metadata_to_example_group?.should be_true
        end
      end

      describe '-p/--no-parens-matcher-arg option' do
        let(:args) { ['--no-parens-matcher-arg'] }

        it 'sets Config#parenthesize_matcher_arg? false' do
          parser.parse(args)
          config.parenthesize_matcher_arg.should be_false
        end
      end

      describe '--no-parentheses-matcher-arg option' do
        let(:args) { ['--no-parentheses-matcher-arg'] }

        before do
          parser.stub(:warn)
        end

        it 'sets Config#parenthesize_matcher_arg? false' do
          parser.parse(args)
          config.parenthesize_matcher_arg.should be_false
        end

        it 'is deprecated' do
          parser.should_receive(:warn) do |message|
            message.should =~ /--no-parentheses-matcher-arg.+deprecated/i
          end

          parser.parse(args)
        end
      end

      describe '--no-color option' do
        before do
          Rainbow.enabled = true
        end

        let(:args) { ['--no-color'] }

        it 'disables color in the output' do
          parser.parse(args)
          Rainbow.enabled.should be_false
        end
      end

      describe '--version option' do
        before do
          parser.stub(:puts)
          parser.stub(:exit)
        end

        let(:args) { ['--version'] }

        it 'shows version' do
          parser.should_receive(:puts).with(Version.to_s)
          parser.parse(args)
        end

        it 'exits' do
          parser.should_receive(:exit)
          parser.parse(args)
        end
      end
    end

    describe 'help text' do
      subject(:help_text) do
        parser.help
      end

      it 'does not exceed 100 characters in each line' do
        help_text.each_line do |line|
          line.chomp.length.should <= 100
        end
      end

      def description_for_option(option)
        description_lines = parser.send(:descriptions)[option]
        description_lines.map { |line| parser.send(:highlight_text, line) }
      end

      def conversion_types_for_option(option)
        section = description_for_option(option)

        section.each_with_object([]) do |line, types|
          match = line.match(/^[ ]{2}([a-z_]+)/)
          next unless match
          types << match.captures.first
        end
      end

      it 'describes all conversion types for -k/--keep option' do
        conversion_types = conversion_types_for_option('-k')
        expected_types =
          Config::DEFAULT_CONVERSIONS.select { |_, enabled| enabled }.keys.map(&:to_s)
        conversion_types.should =~ expected_types
      end

      it 'describes all conversion types for -v/--convert option' do
        conversion_types = conversion_types_for_option('-v')
        expected_types =
          Config::DEFAULT_CONVERSIONS.reject { |_, enabled| enabled }.keys.map(&:to_s)
        conversion_types.should =~ expected_types
      end
    end
  end
end
