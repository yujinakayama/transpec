# coding: utf-8

require 'rspec/expectations'
require_relative 'project'

class Test < Project
  include RSpec::Matchers

  attr_reader :simple
  alias_method :simple?, :simple

  def initialize(url, ref = nil, bundler_args = [], simple = false)
    super(url, ref, bundler_args)
    @simple = simple
  end

  def run
    puts " Testing transpec on #{name} project ".center(80, '=')

    setup

    in_project_dir do
      transpec '--force'
      sh 'bundle exec rspec'
      return if simple?
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
    if File.exist?(commit_message_fixture_path)
      summary = summary_in_commit_message(File.read(commit_message_path))
      expected_summary = summary_in_commit_message(File.read(commit_message_fixture_path))
      expect(summary).to eq(expected_summary)
    else
      warn "#{commit_message_fixture_path} does not exist. Copying from #{commit_message_path}."
      FileUtils.mkdir_p(File.dirname(commit_message_fixture_path))
      FileUtils.cp(commit_message_path, commit_message_fixture_path)
    end
  end

  def summary_in_commit_message(message)
    message.lines.to_a[5..-1].join("\n")
  end

  def commit_message_path
    File.join(project_dir, '.git', 'COMMIT_EDITMSG')
  end

  def commit_message_fixture_path
    path = File.join(Transpec.root, 'tasks', 'fixtures', name, 'COMMIT_EDITMSG')
    File.expand_path(path)
  end
end
