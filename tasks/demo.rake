# coding: utf-8

require_relative 'lib/transpec_demo'

namespace :demo do
  # rubocop:disable LineLength
  demos = [
    TranspecDemo.new('git@github.com:yujinakayama/twitter.git', 'v4.1.0'),
    TranspecDemo.new('git@github.com:yujinakayama/guard.git', 'transpec-test', %w(--without development)),
    TranspecDemo.new('git@github.com:yujinakayama/mail.git', 'transpec-test')
  ]
  # rubocop:enable LineLength

  desc 'Run demo of Transpec on all projects'
  task all: demos.map(&:name)

  demos.each do |demo|
    desc "Run demo of Transpec on #{demo.name.capitalize} project"
    task demo.name do
      demo.run
    end
  end
end
