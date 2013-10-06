# coding: utf-8

require 'rainbow'

module Transpec
  class Report
    attr_reader :records, :invalid_context_errors, :syntax_errors

    def initialize
      @records = []
      @invalid_context_errors = []
      @syntax_errors = []
    end

    def unique_record_counts
      record_counts = Hash.new(0)

      records.each do |record|
        record_counts[record] += 1
      end

      Hash[record_counts.sort_by { |record, count| -count }]
    end

    def colored_summary(options = nil)
      options ||= { bullet: nil, separate_by_blank_line: false }

      entry_prefix = options[:bullet] ? options[:bullet] + ' ' : ''
      indentation = if options[:bullet]
                      ' ' * entry_prefix.length
                    else
                      ''
                    end

      summary = ''

      unique_record_counts.each do |record, count|
        summary << "\n" if options[:separate_by_blank_line] && !summary.empty?
        summary << entry_prefix + pluralize(count, 'conversion').color(:cyan) + "\n"
        summary << indentation + '  ' + 'from: '.color(:cyan) + record.original_syntax + "\n"
        summary << indentation + '    ' + 'to: '.color(:cyan) + record.converted_syntax + "\n"
      end

      summary
    end

    def summary(options = nil)
      without_color { colored_summary(options) }
    end

    def colored_stats
      color = invalid_context_errors.count == 0 ? :green : :yellow

      stats = pluralize(records.count, 'conversion') + ', '
      stats << pluralize(invalid_context_errors.count, 'incomplete') + ', '
      stats = stats.color(color)

      error_color = syntax_errors.count == 0 ? color : :red
      stats << pluralize(syntax_errors.count, 'error').color(error_color)
    end

    def stats
      without_color { colored_stats }
    end

    private

    def without_color
      # TODO: Consider using another coloring gem that does not depend global state.
      original_coloring_state = Sickill::Rainbow.enabled
      Sickill::Rainbow.enabled = false
      value = yield
      Sickill::Rainbow.enabled = original_coloring_state
      value
    end

    def pluralize(number, thing, options = {})
      text = ''

      if number == 0 && options[:no_for_zero]
        text = 'no'
      else
        text << number.to_s
      end

      text << " #{thing}"
      text << 's' unless number == 1

      text
    end
  end
end
