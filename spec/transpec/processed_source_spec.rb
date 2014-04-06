# coding: utf-8

require 'spec_helper'
require 'transpec/processed_source'

module Transpec
  describe ProcessedSource do
    describe '.parse_file' do
      include FileHelper
      include_context 'isolated environment'

      let(:spec_path) { 'spec/example_spec.rb' }

      before do
        create_file(spec_path, "puts 'foo'")
      end

      it 'parses the file and returns processed source' do
        processed_source = ProcessedSource.parse_file(spec_path)
        processed_source.path.should == spec_path
        processed_source.ast.should_not be_nil
      end
    end

    describe '.parse' do
      it 'parses the source and returns processed source' do
        processed_source = ProcessedSource.parse("puts 'foo'")
        processed_source.ast.should_not be_nil
      end

      context 'when a file path is passed' do
        let(:spec_path) { 'spec/example_spec.rb' }

        it 'sets the path to the instance' do
          processed_source = ProcessedSource.parse("puts 'foo'", spec_path)
          processed_source.path.should == spec_path
        end
      end

      context 'when no file path is passed' do
        it 'does not set the path to the instance' do
          processed_source = ProcessedSource.parse("puts 'foo'")
          processed_source.path.should be_nil
        end
      end

      context 'when the file has invalid source' do
        it 'sets syntax error to the instance' do
          processed_source = ProcessedSource.parse('<')
          processed_source.syntax_error.should be_a(Parser::SyntaxError)
        end
      end
    end

    describe '#to_s' do
      it 'returns the original source' do
        source = [
          "puts 'foo'",
          "puts 'bar'"
        ].join("\n")

        processed_source = ProcessedSource.parse(source)
        processed_source.to_s.should == source
      end
    end
  end
end
