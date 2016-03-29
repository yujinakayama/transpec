# coding: utf-8

tasks = %w(spec)

if RSpec::Core::Version::STRING.start_with?('2.14') && RUBY_ENGINE != 'jruby'
  tasks.concat(%w(style readme:check test:all))
end

task ci: tasks
