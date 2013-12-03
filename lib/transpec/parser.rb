# coding: utf-8

begin
  require 'parser/current'
rescue NotImplementedError
  warn 'Falling back to Ruby 2.0 parser.'
  require 'parser/ruby20'
  Parser::CurrentRuby = Parser::Ruby20 # rubocop:disable ConstantName
end
