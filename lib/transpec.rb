# coding: utf-8

require 'transpec/rspec_version'

module Transpec
  def self.root
    File.expand_path('..', File.dirname(__FILE__))
  end

  def self.required_rspec_version
    @required_rspec_version ||= begin
      gemspec_path = File.join(root, 'transpec.gemspec')
      gem_specification = Gem::Specification.load(gemspec_path)
      rspec_dependency = gem_specification.dependencies.find { |d| d.name == 'rspec' }

      if rspec_dependency
        rspec_requirement = rspec_dependency.requirement
        gem_version = rspec_requirement.requirements.first.find { |r| r.is_a?(Gem::Version) }
        RSpecVersion.new(gem_version.to_s)
      else
        # Using development version of RSpec with Bundler.
        current_rspec_version
      end
    end
  end

  def self.current_rspec_version
    require 'rspec/version'
    RSpecVersion.new(RSpec::Version::STRING)
  end
end
