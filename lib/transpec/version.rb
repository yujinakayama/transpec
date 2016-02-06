# coding: utf-8

module Transpec
  # http://semver.org/
  module Version
    MAJOR = 3
    MINOR = 2
    PATCH = 0

    def self.to_s
      [MAJOR, MINOR, PATCH].join('.')
    end
  end
end
