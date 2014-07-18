# coding: utf-8

# This context requires `source` to be defined with #let.
shared_context 'parsed objects' do
  let(:source_path) { nil }

  let(:processed_source) do
    require 'transpec/processed_source'
    Transpec::ProcessedSource.new(source, source_path)
  end

  let(:ast) do
    processed_source.ast
  end

  let(:source_rewriter) do
    require 'parser'
    Parser::Source::Rewriter.new(processed_source.buffer)
  end

  let(:rewritten_source) { source_rewriter.process }

  # Include 'dynamic analysis objects' after this context so that this nil will be overridden.
  let(:runtime_data) { nil }
end

# This context requires `source` to be defined with #let.
shared_context 'dynamic analysis objects' do
  include_context 'isolated environment'

  let(:source_path) { 'spec/example_spec.rb' }

  runtime_data_cache = {}

  let(:runtime_data) do
    require 'transpec/dynamic_analyzer'

    if runtime_data_cache[source]
      runtime_data_cache[source]
    else
      FileHelper.create_file(source_path, source)
      dynamic_analyzer = Transpec::DynamicAnalyzer.new(silent: true)
      runtime_data_cache[source] = dynamic_analyzer.analyze
    end
  end
end

# This context depends on the context 'parsed objects'.
shared_context 'syntax object' do |syntax_class, name|
  let(name) do
    ast.each_node do |node|
      syntax = syntax_class.new(node, source_rewriter, runtime_data)
      return syntax if syntax.conversion_target?
    end

    fail "No #{syntax_class.name} conversion target is found!"
  end
end

shared_context 'isolated environment' do
  around do |example|
    require 'tmpdir'
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
