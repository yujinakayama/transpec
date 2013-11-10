# coding: utf-8

require 'json'
require 'ostruct'
require 'pathname'

module Transpec
  class DynamicAnalyzer
    class RuntimeData
      attr_reader :data

      def self.load(string_or_io)
        options = { object_class: CompatibleOpenStruct, symbolize_names: true }
        data = JSON.load(string_or_io, nil, options)
        new(data)
      end

      def initialize(data = CompatibleOpenStruct.new)
        @data = data
      end

      def [](node)
        @data[node_id(node)]
      end

      def node_id(node)
        source_range = node.loc.expression
        source_buffer = source_range.source_buffer
        absolute_path = File.expand_path(source_buffer.name)
        relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.pwd).to_s
        [relative_path, source_range.begin_pos, source_range.end_pos].join('_')
      end

      class CompatibleOpenStruct < OpenStruct
        # OpenStruct#[] is available from Ruby 2.0.
        unless method_defined?(:[])
          def [](key)
            __send__(key)
          end
        end

        unless method_defined?(:[]=)
          def []=(key, value)
            __send__("#{key}=", value)
          end
        end
      end
    end
  end
end
