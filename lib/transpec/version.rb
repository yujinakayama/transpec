# coding: utf-8

module Transpec
  # http://semver.org/
  module Version
    MAJOR = 0
    MINOR = 2
    PATCH = 2

    def self.to_s
      [MAJOR, MINOR, PATCH].join('.')
    end
  end
end
