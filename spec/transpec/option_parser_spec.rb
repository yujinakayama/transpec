# coding: utf-8

require 'spec_helper'
require 'transpec/option_parser'

module Transpec
  describe OptionParser do
    subject(:parser) { OptionParser.new(configuration) }
    let(:configuration) { Configuration.new }

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

        it 'sets Configuration#forced? true' do
          parser.parse(args)
          configuration.forced?.should be_true
        end
      end

      describe '-m/--generate-commit-message option' do
        include_context 'isolated environment'

        let(:args) { ['--generate-commit-message'] }

        context 'when inside of git repository' do
          include_context 'inside of git repository'

          it 'sets Configuration#generate_commit_message? true' do
            parser.parse(args)
            configuration.generate_commit_message?.should be_true
          end
        end

        context 'when not inside of git repository' do
          it 'raises error' do
            -> { parser.parse(args) }.should raise_error(/not in a Git repository/)
          end
        end
      end

      describe '-d/--disable option' do
        [
          ['expect_to_matcher', :convert_to_expect_to_matcher?],
          ['expect_to_receive', :convert_to_expect_to_receive?],
          ['allow_to_receive',  :convert_to_allow_to_receive?],
          ['have_items',        :convert_have_items],
          ['deprecated',        :replace_deprecated_method?]
        ].each do |cli_type, config_attr|
          context "when #{cli_type.inspect} is specified" do
            let(:args) { ['--disable', cli_type] }

            it "sets Configuration##{config_attr} false" do
              parser.parse(args)
              configuration.send(config_attr).should be_false
            end
          end
        end

        context 'when multiple types are specified with comma' do
          let(:args) { ['--disable', 'allow_to_receive,deprecated'] }

          it 'handles all of them' do
            parser.parse(args)
            configuration.convert_to_allow_to_receive?.should be_false
            configuration.replace_deprecated_method?.should be_false
          end
        end

        context 'when unknown type is specified' do
          let(:args) { ['--disable', 'unknown'] }

          it 'raises error' do
            -> { parser.parse(args) }.should raise_error(ArgumentError) { |error|
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
              parser.parse(args)
              configuration.negative_form_of_to.should == form
            end
          end
        end
      end

      describe '-p/--no-parentheses-matcher-arg option' do
        let(:args) { ['--no-parentheses-matcher-arg'] }

        it 'sets Configuration#parenthesize_matcher_arg? false' do
          parser.parse(args)
          configuration.parenthesize_matcher_arg.should be_false
        end
      end

      describe '--no-color option' do
        before do
          Sickill::Rainbow.enabled = true
        end

        let(:args) { ['--no-color'] }

        it 'disables color in the output' do
          parser.parse(args)
          Sickill::Rainbow.enabled.should be_false
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
        parser.parser.help
      end

      it 'does not exceed 80 characters in each line' do
        help_text.each_line do |line|
          line.chomp.length.should <= 80
        end
      end

      it 'describes all conversion types for -d/--disable option' do
        option_sections = help_text.lines.slice_before(/^\s*-/)

        disable_section = option_sections.find do |lines|
          lines.first =~ /^\s*-d/
        end

        conversion_types = disable_section.reduce([]) do |types, line|
          match = line.match(/^[ ]{39}([a-z_]+)/)
          next types unless match
          types << match.captures.first
        end

        conversion_types.should =~ OptionParser::CONFIG_ATTRS_FOR_CLI_TYPES.keys.map(&:to_s)
      end
    end
  end
end
