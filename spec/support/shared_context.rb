# coding: utf-8

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
    parser = Parser::CurrentRuby.new
    ast = parser.parse(source_buffer)
    ast
  end

  let(:source_rewriter) { Parser::Source::Rewriter.new(source_buffer) }

  let(:rewritten_source) { source_rewriter.process }
end

shared_context 'should object' do
  let(:should_object) do
    Transpec::AST::Scanner.scan(ast) do |node, ancestor_nodes, in_example_group_context|
      next unless Transpec::Syntax::Should.target_node?(node)
      return Transpec::Syntax::Should.new(
        node,
        ancestor_nodes,
        in_example_group_context?,
        source_rewriter
      )
    end

    fail 'No should node is found!'
  end

  let(:in_example_group_context?) { true }
end

shared_context 'isolated environment' do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      original_home = ENV['HOME']

      begin
        virtual_home = File.expand_path(File.join(tmpdir, 'home'))
        Dir.mkdir(virtual_home)
        ENV['HOME'] = virtual_home

        working_dir = File.join(tmpdir, 'work')
        Dir.mkdir(working_dir)

        Dir.chdir(working_dir) do
          example.run
        end
      ensure
        ENV['HOME'] = original_home
      end
    end
  end
end
