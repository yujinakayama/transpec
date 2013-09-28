# coding: utf-8

RSpec.configure do |config|
  # Yes, I'm writing specs in should syntax intentionally!
  config.expect_with :rspec do |c|
    c.syntax = :should
  end

  config.mock_with :rspec do |c|
    c.syntax = :should
  end

  config.color_enabled = true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run_excluding do_not_run_in_converted_spec: ENV['TRANSPEC_CONVERTED_SPEC']

  config.before(:all) do
    require 'rainbow'
    Sickill::Rainbow.enabled = false

    if ENV['TRAVIS']
      system('git config --global user.email "you@example.com"')
      system('git config --global user.name "Your Name"')
    end
  end
end

unless ENV['TRANSPEC_CONVERTED_SPEC']
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
end

Dir[File.join(File.dirname(__FILE__), 'support', '*')].each do |path|
  require path
end
