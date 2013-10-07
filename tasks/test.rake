# coding: utf-8

require_relative 'lib/transpec_test'

namespace :test do
  # On Travis CI, reuse system gems to speed up build.
  bundler_args = if ENV['TRAVIS']
                   []
                 else
                   %w(--path vendor/bundle)
                 end

  # rubocop:disable LineLength
  tests = [
    TranspecTest.new(File.expand_path('.'), nil, ['--quiet']),
    TranspecTest.new('https://github.com/sferik/twitter.git', 'v4.1.0', bundler_args),
    TranspecTest.new('https://github.com/yujinakayama/guard.git', 'transpec', bundler_args + %w(--without development)),
    TranspecTest.new('https://github.com/yujinakayama/mail.git', 'transpec', bundler_args)
  ]
  # rubocop:enable LineLength

  desc 'Test Transpec on all projects'
  task all: tests.map(&:name)

  tests.each do |test|
    desc "Test Transpec on #{test.name.capitalize} project"
    task test.name do
      test.run
    end
  end
end
