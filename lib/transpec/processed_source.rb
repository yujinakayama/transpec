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

    def self.parse_file(path)
      source = File.read(path)
      parse(source, path)
    end

    def self.parse(source, path = nil)
      buffer = Parser::Source::Buffer.new(path || '(string)')
      buffer.source = source

      builder = AST::Builder.new
      parser = Parser::CurrentRuby.new(builder)

      begin
        ast = parser.parse(buffer)
        new(buffer, ast, path)
      rescue Parser::SyntaxError => error
        new(buffer, nil, path, error)
      end
    end

    def initialize(buffer, ast, path = nil, syntax_error = nil)
      @buffer = buffer
      @ast = ast
      @path = path
      @syntax_error = syntax_error
    end

    def to_s
      buffer.source
    end
  end
end
