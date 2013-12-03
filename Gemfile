source 'https://rubygems.org'

gemspec

gem 'rubocop', github: 'bbatsov/rubocop' if RUBY_VERSION.start_with?('2.2')

group :test do
  gem 'coveralls',      '~> 0.6'
  gem 'simplecov-rcov', '~> 0.2'
  gem 'ci_reporter',    '~> 1.8'
end
