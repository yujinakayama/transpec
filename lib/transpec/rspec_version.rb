# coding: utf-8

require 'transpec'

module Transpec
  # Gem::Version caches its instances with class variable @@all,
  # so we should not inherit it.
  class RSpecVersion
    include Comparable

    # http://www.ruby-doc.org/stdlib-2.0.0/libdoc/rubygems/rdoc/Gem/Version.html
    #
    # If any part contains letters (currently only a-z are supported) then that version is
    # considered prerelease.
    # Prerelease parts are sorted alphabetically using the normal Ruby string sorting rules.
    # If a prerelease part contains both letters and numbers, it will be broken into multiple parts
    # to provide expected sort behavior (1.0.a10 becomes 1.0.a.10, and is greater than 1.0.a9).
    GEM_VERSION_2_99_BETA1 = Gem::Version.new('2.99.beta1')
    GEM_VERSION_3_0_BETA1  = Gem::Version.new('3.0.beta1')

    attr_reader :gem_version

    def initialize(version)
      @gem_version = if version.is_a?(Gem::Version)
                       version
                     else
                       Gem::Version.new(version)
                     end
    end

    def be_truthy_available?
      @gem_version >= GEM_VERSION_2_99_BETA1
    end

    def receive_messages_available?
      @gem_version >= GEM_VERSION_3_0_BETA1
    end

    def yielded_example_available?
      @gem_version >= GEM_VERSION_2_99_BETA1
    end

    def <=>(other)
      @gem_version <=> other.gem_version
    end

    def to_s
      @gem_version.to_s
    end
  end
end
