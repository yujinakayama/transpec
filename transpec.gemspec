# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'transpec/version'

Gem::Specification.new do |spec|
  spec.name          = 'transpec'
  spec.version       = Transpec::Version.to_s
  spec.authors       = ['Yuji Nakayama']
  spec.email         = ['nkymyj@gmail.com']
  spec.summary       = 'The RSpec syntax converter'
  spec.description   = 'Transpec converts your specs to the latest RSpec syntax ' +
                       'with static and dynamic code analysis.'
  spec.homepage      = 'http://yujinakayama.me/transpec/'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_runtime_dependency 'parser',        '>= 2.2.0.pre.3', '< 3.0'
  spec.add_runtime_dependency 'astrolabe',     '>= 0.6', '< 0.7'
  spec.add_runtime_dependency 'bundler',       '~> 1.3'
  spec.add_runtime_dependency 'rainbow',       '>= 1.99.1', '< 3.0'
  spec.add_runtime_dependency 'json',          '~> 1.8'
  spec.add_runtime_dependency 'activesupport', '>= 3.0', '< 5.0'

  spec.add_development_dependency 'rake',          '~> 10.1'
  spec.add_development_dependency 'rspec',         '~> 2.14.0'
  spec.add_development_dependency 'fuubar',        '~> 1.3'
  spec.add_development_dependency 'simplecov',     '~> 0.7'
  spec.add_development_dependency 'rubocop',       '~> 0.24'
  spec.add_development_dependency 'guard-rspec',   '>= 4.2.3', '< 5.0'
  spec.add_development_dependency 'guard-rubocop', '~> 1.0'
  spec.add_development_dependency 'guard-shell',   '~> 0.5'
  spec.add_development_dependency 'ruby_gntp',     '~> 0.3'
end
