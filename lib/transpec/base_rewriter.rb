# coding: utf-8

require 'transpec/processed_source'

module Transpec
  class BaseRewriter
    def rewrite_file!(arg)
      processed_source = case arg
                         when String          then ProcessedSource.parse_file(arg)
                         when ProcessedSource then arg
                         else fail "Invalid argument: #{arg}"
                         end

      fail 'ProcessedSource must be derived from a file' unless processed_source.path

      rewritten_source = rewrite(processed_source)
      return if processed_source.to_s == rewritten_source
      File.write(processed_source.path, rewritten_source)
    end

    def rewrite_source(source, path = nil)
      processed_source = ProcessedSource.parse(source, path)
      rewrite(processed_source)
    end

    def rewrite(processed_source)
      fail processed_source.syntax_error if processed_source.syntax_error

      source_rewriter = Parser::Source::Rewriter.new(processed_source.buffer)
      incomplete = false
      source_rewriter.diagnostics.consumer = proc do
        incomplete = true
        fail OverlappedRewriteError
      end

      process(processed_source.ast, source_rewriter)

      rewritten_source = source_rewriter.process
      rewritten_source = rewrite_source(rewritten_source, processed_source.path) if incomplete

      rewritten_source
    end

    private

    def process(ast, source_rewriter)
      fail NotImplementedError
    end

    def create_source_buffer(source, name)
      source_buffer = Parser::Source::Buffer.new(name)
      source_buffer.source = source
      source_buffer
    end

    def parse(source_buffer)
      builder = AST::Builder.new
      parser = Parser::CurrentRuby.new(builder)
      ast = parser.parse(source_buffer)
      ast
    end

    class OverlappedRewriteError < StandardError; end
  end
end
