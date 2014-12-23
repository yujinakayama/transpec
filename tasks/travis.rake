# coding: utf-8

namespace :travis do
  desc 'Validate completeness of available RSpec versions in .travis.yml'
  task :validate_matrix do
    require 'open-uri'
    require 'json'
    require 'yaml'

    json = URI.parse('https://rubygems.org/api/v1/versions/rspec.json').read
    gem_versions = JSON.parse(json)

    available_versions = gem_versions.map do |version|
      major, minor, _patch, _suffix = version['number'].split('.')
      [major, minor].join('.')
    end.uniq.sort

    minimum_support_version = Gem::Version.new('2.14')
    available_versions.reject! { |version| Gem::Version.new(version) < minimum_support_version }

    travis_config = YAML.load_file('.travis.yml')

    travis_versions = travis_config['env'].map do |pair|
      key, value = pair.split('=')
      next unless key == 'RSPEC_VERSION'
      next if value == 'head'
      value
    end.compact.sort

    if travis_versions == available_versions
      puts 'All the available RSpec versions are covered in .travis.yml.'
    else
      fail "The current available RSpec versions are not covered in .travis.yml!\n" \
           "       Available Versions: #{available_versions}\n" \
           "  Versions in .travis.yml: #{travis_versions}"
    end
  end
end
