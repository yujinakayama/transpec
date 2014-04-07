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

    def main_rspec_configure_node?(node)
      analyze

      if @main_rspec_configure
        @main_rspec_configure.node.equal?(node)
      else
        true
      end
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
      invoke_handler(syntax.class, syntax)

      syntax_mixins.each do |mixin|
        next unless syntax.class.ancestors.include?(mixin)
        invoke_handler(mixin, syntax)
      end

      syntax.dependent_syntaxes.each do |dependent_syntax|
        next unless dependent_syntax.conversion_target?
        dispatch_syntax(dependent_syntax)
      end
    end

    def syntax_mixins
      Syntax::Mixin.constants.map do |const_name|
        Syntax::Mixin.const_get(const_name, false)
      end
    end

    def invoke_handler(klass, syntax)
      class_name = klass.name.split('::').last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      handler_name = "process_#{class_name}"
      send(handler_name, syntax) if respond_to?(handler_name, true)
    end

    def process_any_instance_block(syntax)
      @need_to_modify_yield_receiver_to_any_instance_implementation_blocks_config ||=
        syntax.need_to_add_receiver_arg_to_any_instance_implementation_block?
    end

    def process_rspec_configure(rspec_configure)
      return unless runtime_data
      run_order = runtime_data[rspec_configure.node, :run_order]
      return unless run_order

      unless @main_rspec_configure
        @main_rspec_configure = rspec_configure
        return
      end

      if run_order < runtime_data[@main_rspec_configure.node, :run_order]
        @main_rspec_configure = rspec_configure
      end
    end
  end
end
