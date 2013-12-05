# coding: utf-8

require 'transpec'

module Transpec
  # Gem::Version caches its instances with class variable @@all,
  # so we should not inherit it.
  class RSpecVersion
    include Comparable

    attr_reader :gem_version

    def self.define_feature_availability(feature, version_string)
      available_version = new(version_string)

      define_singleton_method("#{feature}_available_version") do
        available_version
      end

      define_method("#{feature}_available?") do
        self >= available_version
      end
    end

    def initialize(version)
      @gem_version = if version.is_a?(Gem::Version)
                       version
                     else
                       Gem::Version.new(version)
                     end
    end

    def <=>(other)
      @gem_version <=> other.gem_version
    end

    def to_s
      @gem_version.to_s
    end

    define_feature_availability :be_truthy,             '2.99.0.beta1'
    define_feature_availability :yielded_example,       '2.99.0.beta1'
    define_feature_availability :one_liner_is_expected, '2.99.0.beta2'
    define_feature_availability :receive_messages,      '3.0.0.beta1'
    define_feature_availability :receive_message_chain, '3.0.0.beta2'
  end
end
