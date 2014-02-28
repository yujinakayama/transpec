# coding: utf-8

require 'transpec/base_rewriter'
require 'transpec/configuration'
require 'transpec/report'
require 'transpec/rspec_version'
require 'transpec/syntax'

Transpec::Syntax.require_all

module Transpec
  class Converter < BaseRewriter # rubocop:disable ClassLength
    attr_reader :configuration, :rspec_version, :runtime_data, :report

    alias_method :convert_file!, :rewrite_file!
    alias_method :convert, :rewrite

    def initialize(configuration = nil, rspec_version = nil, runtime_data = nil)
      @configuration = configuration || Configuration.new
      @rspec_version = rspec_version || Transpec.current_rspec_version
      @runtime_data = runtime_data
      @report = Report.new
    end

    def process(ast, source_rewriter)
      return unless ast
      ast.each_node do |node|
        dispatch_node(node, source_rewriter)
      end
    end

    def dispatch_node(node, source_rewriter)
      Syntax.standalone_syntaxes.each do |syntax_class|
        next unless syntax_class.conversion_target_node?(node, runtime_data)

        syntax = syntax_class.new(node, source_rewriter, runtime_data, report)

        handler_name = "process_#{syntax_class.snake_case_name}"
        send(handler_name, syntax)

        break
      end
    rescue OverlappedRewriteError # rubocop:disable HandleExceptions
    rescue ConversionError => error
      report.conversion_errors << error
    end

    def process_should(should)
      if configuration.convert_should?
        should.expectize!(
          configuration.negative_form_of_to,
          configuration.parenthesize_matcher_arg?
        )
      end

      process_have(should.have_matcher)
      process_raise_error(should.raise_error_matcher)
    end

    def process_oneliner_should(oneliner_should)
      negative_form = configuration.negative_form_of_to
      parenthesize = configuration.parenthesize_matcher_arg?

      # TODO: Referencing oneliner_should.have_matcher.project_requires_collection_matcher?
      #   from this converter is considered bad design.
      should_convert_have_items = configuration.convert_have_items? &&
                                  oneliner_should.have_matcher &&
                                  !oneliner_should.have_matcher.project_requires_collection_matcher?

      if should_convert_have_items
        if configuration.convert_should?
          oneliner_should.convert_have_items_to_standard_expect!(negative_form, parenthesize)
        else
          oneliner_should.convert_have_items_to_standard_should!
        end
      elsif configuration.convert_oneliner? && rspec_version.oneliner_is_expected_available?
        oneliner_should.expectize!(negative_form, parenthesize)
      end

      process_raise_error(oneliner_should.raise_error_matcher)
    end

    def process_expect(expect)
      process_have(expect.have_matcher)
      process_raise_error(expect.raise_error_matcher)
      process_messaging_host(expect.receive_matcher)
    end

    def process_allow(allow)
      process_messaging_host(allow.receive_matcher)
    end

    def process_should_receive(should_receive)
      if should_receive.useless_expectation?
        if configuration.convert_deprecated_method?
          if configuration.convert_stub?
            should_receive.allowize_useless_expectation!(configuration.negative_form_of_to)
          else
            should_receive.stubize_useless_expectation!
          end
        elsif configuration.convert_should_receive?
          should_receive.expectize!(configuration.negative_form_of_to)
        end
      elsif configuration.convert_should_receive?
        should_receive.expectize!(configuration.negative_form_of_to)
      end

      process_messaging_host(should_receive)
    end

    def process_double(double)
      double.convert_to_double! if configuration.convert_deprecated_method?
    end

    def process_method_stub(method_stub)
      if configuration.convert_stub?
        if !method_stub.hash_arg? ||
           rspec_version.receive_messages_available? ||
           configuration.convert_stub_with_hash_to_stub_and_return?
          method_stub.allowize!(rspec_version)
        elsif configuration.convert_deprecated_method?
          method_stub.convert_deprecated_method!
        end
      elsif configuration.convert_deprecated_method?
        method_stub.convert_deprecated_method!
      end

      method_stub.remove_no_message_allowance! if configuration.convert_deprecated_method?

      process_messaging_host(method_stub)
    end

    def process_be_boolean(be_boolean)
      return unless rspec_version.be_truthy_available?
      return unless configuration.convert_deprecated_method?

      case configuration.boolean_matcher_type
      when :conditional
        be_boolean.convert_to_conditional_matcher!(configuration.form_of_be_falsey)
      when :exact
        be_boolean.convert_to_exact_matcher!
      end
    end

    def process_be_close(be_close)
      be_close.convert_to_be_within! if configuration.convert_deprecated_method?
    end

    def process_raise_error(raise_error)
      return unless raise_error
      if configuration.convert_deprecated_method?
        raise_error.remove_error_specification_with_negative_expectation!
      end
    end

    def process_its(its)
      its.convert_to_describe_subject_it! if configuration.convert_its?
    end

    def process_example(example)
      return if !rspec_version.rspec_2_99? || !configuration.convert_deprecated_method?
      example.convert_pending_to_skip!
    end

    def process_pending(pending)
      return if !rspec_version.rspec_2_99? || !configuration.convert_deprecated_method?
      pending.convert_deprecated_syntax!
    end

    def process_current_example(current_example)
      return unless rspec_version.yielded_example_available?
      current_example.convert! if configuration.convert_deprecated_method?
    end

    def process_matcher_definition(matcher_definition)
      return unless rspec_version.non_should_matcher_protocol_available?
      matcher_definition.convert_deprecated_method! if configuration.convert_deprecated_method?
    end

    def process_rspec_configure(rspec_configure)
      if need_to_modify_expectation_syntax_configuration?(rspec_configure)
        rspec_configure.expectations.syntaxes = :expect
      end

      if need_to_modify_mock_syntax_configuration?(rspec_configure)
        rspec_configure.mocks.syntaxes = :expect
      end

      if rspec_version.rspec_2_99? &&
           configuration.convert_deprecated_method?
        should_yield = configuration.add_receiver_arg_to_any_instance_implementation_block?
        rspec_configure.mocks.yield_receiver_to_any_instance_implementation_blocks = should_yield
      end
    end

    def process_have(have)
      return if !have || !configuration.convert_have_items?
      have.convert_to_standard_expectation!(configuration.parenthesize_matcher_arg)
    end

    def process_messaging_host(messaging_host)
      process_useless_and_return(messaging_host)
      process_any_instance_block(messaging_host)
    end

    def process_useless_and_return(messaging_host)
      return unless messaging_host
      return unless configuration.convert_deprecated_method?
      messaging_host.remove_useless_and_return!
    end

    def process_any_instance_block(messaging_host)
      return unless messaging_host
      return unless rspec_version.rspec_2_99?
      return unless configuration.convert_deprecated_method?
      return unless configuration.add_receiver_arg_to_any_instance_implementation_block?
      messaging_host.add_receiver_arg_to_any_instance_implementation_block!
    end

    def need_to_modify_expectation_syntax_configuration?(rspec_configure)
      return false unless configuration.convert_should?
      rspec_configure.expectations.syntaxes == [:should]
    rescue Syntax::RSpecConfigure::Framework::UnknownSyntaxError
      false
    end

    def need_to_modify_mock_syntax_configuration?(rspec_configure)
      return false if !configuration.convert_should_receive? &&
                      !configuration.convert_stub?
      rspec_configure.mocks.syntaxes == [:should]
    rescue Syntax::RSpecConfigure::Framework::UnknownSyntaxError
      false
    end
  end
end
