# coding: utf-8

require 'transpec'

module Transpec
  class RSpecVersion < Gem::Version
    # http://www.ruby-doc.org/stdlib-2.0.0/libdoc/rubygems/rdoc/Gem/Version.html
    #
    # If any part contains letters (currently only a-z are supported) then that version is
    # considered prerelease.
    # Prerelease parts are sorted alphabetically using the normal Ruby string sorting rules.
    # If a prerelease part contains both letters and numbers, it will be broken into multiple parts
    # to provide expected sort behavior (1.0.a10 becomes 1.0.a.10, and is greater than 1.0.a9).
    VERSION_2_99 = new('2.99.aaaaaaaaaa')
    VERSION_3_0  = new('3.0.aaaaaaaaaa')

    def be_truthy_available?
      self >= VERSION_2_99
    end

    def receive_messages_available?
      self >= VERSION_3_0
    end
  end
end
