# coding: utf-8

begin
  require 'parser/current'
rescue NotImplementedError
  warn 'Falling back to Ruby 2.1 parser.'
  require 'parser/ruby21'
  Parser::CurrentRuby = Parser::Ruby21 # rubocop:disable ConstantName
end
