# coding: utf-8

require 'spec_helper'
require 'tmpdir'
require 'English'

describe 'Transpec project spec', :do_not_run_in_transpeced_spec do
  around do |example|
    Dir.chdir(project_root) do
      example.run
    end
  end

  let(:project_root) do
    File.expand_path('..', File.dirname(__FILE__))
  end

  let(:spec_dir) do
    File.join(project_root, 'spec')
  end

  TRANSPECED_SPEC_DIR = File.join(Dir.mktmpdir, 'transpeced_spec')

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
    FileUtils.cp_r(spec_dir, TRANSPECED_SPEC_DIR)
    silent_system('./bin/transpec', '--force', TRANSPECED_SPEC_DIR).should be_true
  end

  describe 'converted spec' do
    it 'passes all' do
      pending 'Need to rewrite syntax configuration in RSpec.configure'
      env = { 'TRANSPECED_SPEC' => 'true' }
      silent_system(env, 'rspec', TRANSPECED_SPEC_DIR).should be_true
    end
  end
end
