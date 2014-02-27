# coding: utf-8

require 'transpec/util'
require 'json'
require 'ostruct'
require 'pathname'

module Transpec
  class DynamicAnalyzer
    class RuntimeData
      include Util

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
        data[node_id(node)]
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
