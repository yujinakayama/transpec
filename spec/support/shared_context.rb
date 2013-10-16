# coding: utf-8

require 'transpec/dynamic_analyzer'
require 'transpec/ast/builder'
require 'transpec/ast/scanner'
require 'transpec/syntax/should'
require 'parser'
require 'parser/current'
require 'tmpdir'

# This context requires `source` to be defined with #let.
shared_context 'parsed objects' do
  let(:source_buffer) do
    buffer = Parser::Source::Buffer.new('(string)')
    buffer.source = source
    buffer
  end

  let(:ast) do
    builder = Transpec::AST::Builder.new
    parser = Parser::CurrentRuby.new(builder)
    parser.parse(source_buffer)
  end

  let(:source_rewriter) { Parser::Source::Rewriter.new(source_buffer) }

  let(:rewritten_source) { source_rewriter.process }
end

# This context requires `source` to be defined with #let.
shared_context 'dynamic analysis objects' do
  include_context 'isolated environment'

  let(:source_path) { 'spec/example_spec.rb' }

  let(:source_buffer) do
    buffer = Parser::Source::Buffer.new(source_path)
    buffer.source = source
    buffer
  end

  let(:runtime_data) do
    FileHelper.create_file(source_path, source)
    Transpec::DynamicAnalyzer.new(nil, nil, true).analyze
  end
end

shared_context 'should object' do
  let(:should_object) do
    Transpec::AST::Scanner.scan(ast) do |node, ancestor_nodes|
      next unless Transpec::Syntax::Should.conversion_target_node?(node)
      return Transpec::Syntax::Should.new(
        node,
        ancestor_nodes,
        source_rewriter
      )
    end

    fail 'No should node is found!'
  end
end

shared_context 'isolated environment' do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end
end

shared_context 'inside of git repository' do
  around do |example|
    Dir.mkdir('repo')
    Dir.chdir('repo') do
      `git init`
      example.run
    end
  end
end
