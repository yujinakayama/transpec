# coding: utf-8

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    # Yes, I'm writing specs in should syntax intentionally!
    c.syntax = :should
  end

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run_excluding do_not_run_in_transpeced_spec: ENV['TRANSPECED_SPEC']
end

Dir[File.join(File.dirname(__FILE__), 'support', '*')].each do |path|
  require path
end

require 'simplecov'
SimpleCov.coverage_dir(File.join('spec', 'coverage'))

if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
elsif ENV['CI']
  require 'simplecov-rcov'
  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
end

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/bundle/'
end
