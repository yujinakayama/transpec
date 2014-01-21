# coding: utf-8

module Transpec
  # http://semver.org/
  module Version
    MAJOR = 1
    MINOR = 7
    PATCH = 0

    def self.to_s
      [MAJOR, MINOR, PATCH].join('.')
    end
  end
end
