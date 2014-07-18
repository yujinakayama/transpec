# coding: utf-8

begin
  require 'parser/current'
rescue NotImplementedError
  warn 'Falling back to Ruby 2.1 parser.'
  require 'parser/ruby21'
  Parser::CurrentRuby = Parser::Ruby21 # rubocop:disable ConstantName
end

require 'transpec/ast/builder'

module Transpec
  class ProcessedSource
    attr_reader :buffer, :ast, :path, :syntax_error

    def self.from_file(path)
      source = File.read(path)
      new(source, path)
    end

    def initialize(source, path = nil)
      @path = path
      parse(source)
    end

    def to_s
      buffer.source
    end

    private

    def parse(source)
      @buffer = Parser::Source::Buffer.new(@path || '(string)')
      @buffer.source = source

      builder = AST::Builder.new
      parser = Parser::CurrentRuby.new(builder)

      begin
        @ast = parser.parse(@buffer)
      rescue Parser::SyntaxError => error
        @syntax_error = error
      end
    end
  end
end
