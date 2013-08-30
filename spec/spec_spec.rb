# coding: utf-8

require 'spec_helper'
require 'transpec'
require 'tmpdir'
require 'English'

describe 'Transpec project spec', :do_not_run_in_converted_spec do
  copied_project_root = Dir.mktmpdir

  before(:all) do
    Dir.chdir(Transpec.root) do
      FileUtils.cp_r(Dir['*'], copied_project_root)
    end
  end

  around do |example|
    Dir.chdir(copied_project_root) do
      example.run
    end
  end

  def silent_system(*args)
    original_env = ENV.to_hash

    if args.first.is_a?(Hash)
      custom_env = args.shift
      ENV.update(custom_env)
    end

    command = args.shelljoin
    `#{command}`

    ENV.replace(original_env)
    $CHILD_STATUS.success?
  rescue
    ENV.replace(original_env)
    false
  end

  it 'can be converted by Transpec itself without error' do
    silent_system('./bin/transpec', '--force').should be_true
  end

  describe 'converted spec' do
    it 'passes all' do
      env = { 'TRANSPEC_CONVERTED_SPEC' => 'true' }
      silent_system(env, 'rspec').should be_true
    end
  end
end
