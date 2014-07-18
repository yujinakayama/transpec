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
        processed_source = ProcessedSource.from_file(spec_path)
        processed_source.path.should == spec_path
        processed_source.ast.should_not be_nil
      end
    end

    subject(:processed_source) { ProcessedSource.new(source) }

    describe '#ast' do
      let(:source) { "puts 'foo'" }

      it 'returns the root node of AST' do
        processed_source.ast.should be_a(Parser::AST::Node)
      end
    end

    describe '#path' do
      let(:source) { "puts 'foo'" }

      context 'when a file path is passed to .new' do
        subject(:processed_source) { ProcessedSource.new(source, '/path/to/file') }

        it 'returns the path' do
          processed_source.path.should == '/path/to/file'
        end
      end

      context 'when no file path is passed to .new' do
        it 'returns nil' do
          processed_source.path.should be_nil
        end
      end
    end

    describe '#syntax_error' do
      context 'when the source is valid' do
        let(:source) { "puts 'foo'" }

        it 'returns nil' do
          processed_source.error.should be_nil
        end
      end

      context 'when the source is invalid' do
        let(:source) { '<' }

        it 'returns syntax error' do
          processed_source.error.should be_a(Parser::SyntaxError)
        end
      end

      context 'when the source includes invalid byte sequence for the encoding' do
        it 'returns encoding error' do
          processed_source = ProcessedSource.new(<<-END)
            # coding: utf-8
            \xff
          END
          processed_source.error.should be_a(EncodingError)
        end
      end
    end

    describe '#to_s' do
      it 'returns the original source' do
        source = [
          "puts 'foo'",
          "puts 'bar'"
        ].join("\n")

        processed_source = ProcessedSource.new(source)
        processed_source.to_s.should == source
      end
    end
  end
end
