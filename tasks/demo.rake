# coding: utf-8

require_relative 'lib/transpec_demo'

namespace :demo do
  # rubocop:disable LineLength
  demos = [
    TranspecDemo.new('git@github.com:yujinakayama/twitter.git', 'transpec-test-rspec-2-99'),
    TranspecDemo.new('git@github.com:yujinakayama/guard.git', 'transpec-test-rspec-2-99', %w(--without development)),
    TranspecDemo.new('git@github.com:yujinakayama/mail.git', 'transpec-test-rspec-2-99')
  ]
  # rubocop:enable LineLength

  desc 'Publish conversion example on all projects'
  task all: demos.map(&:name)

  demos.each do |demo|
    desc "Publish conversion example on #{demo.name} project"
    task demo.name do
      demo.run
    end
  end
end
