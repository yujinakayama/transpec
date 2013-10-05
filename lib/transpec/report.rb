# coding: utf-8

module Transpec
  class Report
    attr_reader :records

    def initialize
      @records = []
    end

    def unique_record_counts
      record_counts = Hash.new(0)

      records.each do |record|
        record_counts[record] += 1
      end

      Hash[record_counts.sort_by { |record, count| -count }]
    end

    def summary
      summary = ''

      unique_record_counts.each do |record, count|
        summary << pluralize(count, 'conversion') + "\n"
        summary << "  from: #{record.original_syntax}\n"
        summary << "    to: #{record.converted_syntax}\n"
      end

      summary << "\n"
      summary << pluralize(records.count, 'conversion') + " total\n"

      summary
    end

    private

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
