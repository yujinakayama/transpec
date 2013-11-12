# coding: utf-8

require 'spec_helper'
require 'transpec/project'

module Transpec
  describe Project do
    include FileHelper
    include CacheHelper

    subject(:project) { Project.new }

    describe '#require_bundler?' do
      include_context 'isolated environment'

      subject { project.require_bundler? }

      context 'when the project has a Gemfile' do
        before do
          create_file('Gemfile', '')
        end

        it { should be_true }
      end

      context 'when the project have no Gemfile' do
        it { should be_false }
      end
    end

    describe '#rspec_version' do
      subject(:rspec_version) { project.rspec_version }

      it 'returns an instance of RSpecVersion' do
        should be_a(RSpecVersion)
      end

      context 'when the project has a Gemfile' do
        context 'and depends on RSpec 2.13.0' do
          around do |example|
            with_cached_dir('rspec-2.13.0-project') do |cached|
              unless cached
                create_file('Gemfile', [
                  "source 'https://rubygems.org'",
                  "gem 'rspec-core', '2.13.0'"
                ])

                project.with_bundler_clean_env do
                  `bundle install --path vendor/bundle`
                end
              end

              example.run
            end
          end

          it 'returns the version' do
            rspec_version.to_s.should == '2.13.0'
          end
        end
      end

      context 'when the project has no Gemfile' do
        include_context 'isolated environment'

        it 'returns version of the RSpec that is installed in the system' do
          require 'rspec/core/version'
          rspec_version.to_s.should == RSpec::Core::Version::STRING
        end
      end

      context 'when failed checking version' do
        before do
          IO.stub(:popen).and_return(nil)
        end

        it 'raises error' do
          -> { rspec_version }.should raise_error(/failed checking/i)
        end
      end
    end
  end
end
