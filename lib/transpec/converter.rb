# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/configuration'
require 'transpec/report'
require 'transpec/rspec_version'
require 'transpec/syntax'
require 'transpec/syntax/be_boolean'
require 'transpec/syntax/be_close'
require 'transpec/syntax/double'
require 'transpec/syntax/expect'
require 'transpec/syntax/its'
require 'transpec/syntax/method_stub'
require 'transpec/syntax/raise_error'
require 'transpec/syntax/rspec_configure'
require 'transpec/syntax/should'
require 'transpec/syntax/should_receive'

module Transpec
  class Converter < BaseRewriter
    attr_reader :configuration, :rspec_version, :runtime_data, :report, :invalid_context_errors

    alias_method :convert_file!, :rewrite_file!
    alias_method :convert, :rewrite

    def initialize(configuration = nil, rspec_version = nil, runtime_data = nil, report = nil)
      @configuration = configuration || Configuration.new
      @rspec_version = rspec_version || Transpec.current_rspec_version
      @runtime_data = runtime_data
      @report = report || Report.new
      @invalid_context_errors = []
    end

    def process(ast, source_rewriter)
      return unless ast
      ast.each_node do |node|
        dispatch_node(node, source_rewriter)
      end
    end

    def dispatch_node(node, source_rewriter)
      Syntax.standalone_syntaxes.each do |syntax_class|
        next unless syntax_class.target_node?(node, @runtime_data)

        syntax = syntax_class.new(node, source_rewriter, @runtime_data, @report)

        handler_name = "process_#{syntax_class.snake_case_name}"
        send(handler_name, syntax)

        break
      end
    rescue OverlappedRewriteError # rubocop:disable HandleExceptions
    rescue Syntax::InvalidContextError => error
      @invalid_context_errors << error
    end

    def process_should(should)
      if @configuration.convert_should?
        should.expectize!(
          @configuration.negative_form_of_to,
          @configuration.parenthesize_matcher_arg?
        )
      end

      if should.have_matcher && @configuration.convert_have_items?
        should.have_matcher.convert_to_standard_expectation!
      end
    end

    def process_expect(expect)
      if expect.have_matcher && @configuration.convert_have_items?
        expect.have_matcher.convert_to_standard_expectation!
      end
    end

    def process_should_receive(should_receive)
      if should_receive.useless_expectation?
        if @configuration.convert_deprecated_method?
          if @configuration.convert_stub?
            should_receive.allowize_useless_expectation!(@configuration.negative_form_of_to)
          else
            should_receive.stubize_useless_expectation!
          end
        elsif @configuration.convert_should_receive?
          should_receive.expectize!(@configuration.negative_form_of_to)
        end
      elsif @configuration.convert_should_receive?
        should_receive.expectize!(@configuration.negative_form_of_to)
      end
    end

    def process_double(double)
      double.convert_to_double! if @configuration.convert_deprecated_method?
    end

    def process_method_stub(method_stub)
      if @configuration.convert_stub?
        method_stub.allowize!(@rspec_version.receive_messages_available?)
      elsif @configuration.convert_deprecated_method?
        method_stub.convert_deprecated_method!
      end

      method_stub.remove_allowance_for_no_message! if @configuration.convert_deprecated_method?
    end

    def process_be_boolean(be_boolean)
      return unless @rspec_version.be_truthy_available?
      return unless @configuration.convert_deprecated_method?

      case @configuration.boolean_matcher_type
      when :conditional
        be_boolean.convert_to_conditional_matcher!(@configuration.form_of_be_falsey)
      when :exact
        be_boolean.convert_to_exact_matcher!
      end
    end

    def process_be_close(be_close)
      be_close.convert_to_be_within! if @configuration.convert_deprecated_method?
    end

    def process_raise_error(raise_error)
      if @configuration.convert_deprecated_method?
        raise_error.remove_error_specification_with_negative_expectation!
      end
    end

    def process_its(its)
      its.convert_to_describe_subject_it! if @configuration.convert_its?
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
      return false unless @configuration.convert_should?
      rspec_configure.expectation_syntaxes == [:should]
    rescue Syntax::RSpecConfigure::UnknownSyntaxError
      false
    end

    def need_to_modify_mock_syntax_configuration?(rspec_configure)
      return false if !@configuration.convert_should_receive? &&
                      !@configuration.convert_stub?
      rspec_configure.mock_syntaxes == [:should]
    rescue Syntax::RSpecConfigure::UnknownSyntaxError
      false
    end
  end
end
