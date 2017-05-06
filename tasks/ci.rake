# coding: utf-8

tasks = ['spec']

if RSpec::Core::Version::STRING.start_with?('2.14') && RUBY_ENGINE != 'jruby'
  tasks << 'style' if RUBY_VERSION >= '2.0'
  tasks << 'readme:check'
end

task ci: tasks
