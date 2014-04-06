# coding: utf-8

require 'transpec/file_finder'
require 'transpec/processed_source'

module Transpec
  class SpecSuite
    def initialize(base_paths = [])
      @base_paths = base_paths
    end

    def specs
      @specs ||= begin
        FileFinder.find(@base_paths).map do |path|
          ProcessedSource.parse_file(path)
        end
      end
    end
  end
end
