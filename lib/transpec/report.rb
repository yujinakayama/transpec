# coding: utf-8

require 'rainbow'

module Transpec
  class Report
    attr_reader :records, :context_errors, :syntax_errors

    def initialize
      @records = []
      @context_errors = []
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

      summary = ''

      unique_record_counts.each do |record, count|
        summary << "\n" if options[:separate_by_blank_line] && !summary.empty?
        summary << format_record(record, count, options[:bullet])
      end

      summary
    end

    def summary(options = nil)
      without_color { colored_summary(options) }
    end

    def colored_stats
      convertion_and_incomplete_stats + error_stats
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

    def format_record(record, count, bullet = nil)
      entry_prefix = bullet ? bullet + ' ' : ''
      indentation = if bullet
                      ' ' * entry_prefix.length
                    else
                      ''
                    end

      text = entry_prefix + pluralize(count, 'conversion').color(:cyan) + "\n"
      text << indentation + '  ' + 'from: '.color(:cyan) + record.original_syntax + "\n"
      text << indentation + '    ' + 'to: '.color(:cyan) + record.converted_syntax + "\n"
    end

    def convertion_and_incomplete_stats
      color = context_errors.empty? ? :green : :yellow

      text = pluralize(records.count, 'conversion') + ', '
      text << pluralize(context_errors.count, 'incomplete') + ', '
      text.color(color)
    end

    def error_stats
      color = if !syntax_errors.empty?
                :red
              elsif context_errors.empty?
                :green
              else
                :yellow
              end

      pluralize(syntax_errors.count, 'error').color(color)
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
