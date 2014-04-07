# coding: utf-8

require 'rspec/expectations'
require_relative 'project'

class Test < Project
  include RSpec::Matchers

  def run
    puts " Testing transpec on #{name} project ".center(80, '=')

    setup

    in_project_dir do
      transpec '--force'
      sh 'bundle exec rspec'
      compare_summary!
      add_rspec_3_to_gemfile
      sh 'bundle update'
      transpec '--force', '--convert', 'example_group,hook_scope'
      sh 'bundle exec rspec'
    end
  end

  private

  def transpec(*args)
    sh File.join(Transpec.root, 'bin', 'transpec'), *args
  end

  def add_rspec_3_to_gemfile
    File.open('Gemfile', 'a') do |file|
      file.puts("gem 'rspec', '~> 3.0.0.beta1'")
    end
  end

  def compare_summary!
    unless File.exist?(commit_message_fixture_path)
      warn "#{commit_message_fixture_path} does not exist. Skipping summary comparison."
      return
    end

    summary = File.read(File.join('.git', 'COMMIT_EDITMSG')).lines.to_a[5..-1]
    expected_summary = File.read(commit_message_fixture_path).lines.to_a[5..-1]
    expect(summary).to eq(expected_summary)
  end

  def commit_message_fixture_path
    path = File.join(Transpec.root, 'tasks', 'fixtures', name, 'COMMIT_EDITMSG')
    File.expand_path(path)
  end
end
