# coding: utf-8

require 'transpec/file_finder'
require 'transpec/processed_source'
require 'transpec/syntax'

Transpec::Syntax.require_all

module Transpec
  class SpecSuite
    ANALYSIS_TARGET_CLASSES = [Syntax::Mixin::AnyInstanceBlock]

    attr_reader :runtime_data

    def initialize(base_paths = [], runtime_data = nil)
      @base_paths = base_paths
      @runtime_data = runtime_data
      @analyzed = false
    end

    def specs
      @specs ||= begin
        FileFinder.find(@base_paths).map do |path|
          ProcessedSource.parse_file(path)
        end
      end
    end

    def analyze
      return if @analyzed

      specs.each do |spec|
        next unless spec.ast
        spec.ast.each_node do |node|
          dispatch_node(node)
        end
      end

      @analyzed = true
    end

    def need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config?
      analyze
      @need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config
    end

    private

    def dispatch_node(node)
      Syntax.standalone_syntaxes.each do |syntax_class|
        syntax = syntax_class.new(node, nil, runtime_data)
        next unless syntax.conversion_target?
        dispatch_syntax(syntax)
        break
      end
    end

    def dispatch_syntax(syntax)
      ANALYSIS_TARGET_CLASSES.each do |klass|
        next unless syntax.class.ancestors.include?(klass)
        class_name = klass.name.split('::').last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        handler_name = "process_#{class_name}"
        send(handler_name, syntax)
      end

      syntax.dependent_syntaxes.each do |dependent_syntax|
        next unless dependent_syntax.conversion_target?
        dispatch_syntax(dependent_syntax)
      end
    end

    def process_any_instance_block(syntax)
      @need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config ||=
        syntax.need_to_add_receiver_arg_to_any_instance_implementation_block?
    end
  end
end
