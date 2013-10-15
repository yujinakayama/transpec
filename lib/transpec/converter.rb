# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/report'
require 'transpec/ast/scanner'
require 'transpec/configuration'
require 'transpec/syntax'
require 'transpec/syntax/be_close'
require 'transpec/syntax/double'
require 'transpec/syntax/matcher'
require 'transpec/syntax/method_stub'
require 'transpec/syntax/raise_error'
require 'transpec/syntax/rspec_configure'
require 'transpec/syntax/should'
require 'transpec/syntax/should_receive'

module Transpec
  class Converter < BaseRewriter
    attr_reader :report, :invalid_context_errors

    alias_method :convert_file!, :rewrite_file!
    alias_method :convert, :rewrite

    def initialize(configuration = Configuration.new, report = Report.new)
      @configuration = configuration
      @report = report
      @invalid_context_errors = []
    end

    def process(ast, source_rewriter)
      AST::Scanner.scan(ast) do |node, ancestor_nodes|
        dispatch_node(node, ancestor_nodes, source_rewriter)
      end
    end

    def dispatch_node(node, ancestor_nodes, source_rewriter)
      Syntax.all.each do |syntax_class|
        next unless syntax_class.target_node?(node)

        syntax = syntax_class.new(
          node,
          ancestor_nodes,
          source_rewriter,
          @report
        )

        handler_name = "process_#{syntax_class.snake_case_name}"
        send(handler_name, syntax)

        break
      end
    rescue OverlappedRewriteError # rubocop:disable HandleExceptions
    rescue Syntax::InvalidContextError => error
      @invalid_context_errors << error
    end

    def process_should(should)
      if @configuration.convert_to_expect_to_matcher?
        should.expectize!(
          @configuration.negative_form_of_to,
          @configuration.parenthesize_matcher_arg?
        )
      end
    end

    def process_should_receive(should_receive)
      if should_receive.useless_expectation?
        if @configuration.replace_deprecated_method?
          if @configuration.convert_to_allow_to_receive?
            should_receive.allowize_useless_expectation!(@configuration.negative_form_of_to)
          else
            should_receive.stubize_useless_expectation!
          end
        elsif @configuration.convert_to_expect_to_receive?
          should_receive.expectize!(@configuration.negative_form_of_to)
        end
      elsif @configuration.convert_to_expect_to_receive?
        should_receive.expectize!(@configuration.negative_form_of_to)
      end
    end

    def process_double(double)
      double.convert_to_double! if @configuration.replace_deprecated_method?
    end

    def process_method_stub(method_stub)
      if @configuration.convert_to_allow_to_receive?
        method_stub.allowize!
      elsif @configuration.replace_deprecated_method?
        method_stub.replace_deprecated_method!
      end

      method_stub.remove_allowance_for_no_message! if @configuration.replace_deprecated_method?
    end

    def process_be_close(be_close)
      be_close.convert_to_be_within! if @configuration.replace_deprecated_method?
    end

    def process_raise_error(raise_error)
      if @configuration.replace_deprecated_method?
        raise_error.remove_error_specification_with_negative_expectation!
      end
    end

    def process_rspec_configure(rspec_configure)
      if need_to_modify_expectation_syntax_configuration?(rspec_configure)
        rspec_configure.modify_expectation_syntaxes!(:expect)
      end

      if need_to_modify_mock_syntax_configuration?(rspec_configure)
        rspec_configure.modify_mock_syntaxes!(:expect)
      end
    end

    def need_to_modify_expectation_syntax_configuration?(rspec_configure)
      return false unless @configuration.convert_to_expect_to_matcher?
      rspec_configure.expectation_syntaxes == [:should]
    rescue Syntax::RSpecConfigure::UnknownSyntaxError
      false
    end

    def need_to_modify_mock_syntax_configuration?(rspec_configure)
      return false if !@configuration.convert_to_expect_to_receive? &&
                      !@configuration.convert_to_allow_to_receive?
      rspec_configure.mock_syntaxes == [:should]
    rescue Syntax::RSpecConfigure::UnknownSyntaxError
      false
    end
  end
end
