# coding: utf-8

require 'transpec/ast/builder'
require 'parser/current'

module Transpec
  class BaseRewriter
    def rewrite_file!(file_path)
      source = File.read(file_path)
      rewritten_source = rewrite(source, file_path)
      return if source == rewritten_source
      File.write(file_path, rewritten_source)
    end

    def rewrite(source, name = '(string)')
      source_buffer = create_source_buffer(source, name)
      ast = parse(source_buffer)

      source_rewriter = Parser::Source::Rewriter.new(source_buffer)
      failed_overlapping_rewrite = false
      source_rewriter.diagnostics.consumer = proc do
        failed_overlapping_rewrite = true
        fail OverlappedRewriteError
      end

      process(ast, source_rewriter)

      rewritten_source = source_rewriter.process

      if failed_overlapping_rewrite
        rewriter = self.class.new(@configuration, @report)
        rewritten_source = rewriter.rewrite(rewritten_source, name)
      end

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
