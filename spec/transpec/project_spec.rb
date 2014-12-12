# coding: utf-8

require 'spec_helper'
require 'transpec/project'
require 'active_support/core_ext/string/strip.rb'

module Transpec
  describe Project do
    include FileHelper
    include CacheHelper

    subject(:project) { Project.new }

    describe '#using_bundler?' do
      include_context 'isolated environment'

      subject { project.using_bundler? }

      context 'when the project has a Gemfile.lock' do
        before do
          create_file('Gemfile.lock', '')
        end

        it { should be_true }
      end

      context 'when the project have no Gemfile.lock' do
        it { should be_false }
      end
    end

    describe '#depend_on_rspec_rails?' do
      include_context 'isolated environment'

      subject { project.depend_on_rspec_rails? }

      context 'when the project has a Gemfile.lock' do
        before do
          create_file('Gemfile.lock', gemfile_content)
        end

        context 'and rspec-rails is bundled' do
          let(:gemfile_content) do
            <<-END.strip_heredoc
              GEM
                remote: https://rubygems.org/
                specs:
                  actionpack (4.1.7)
                    actionview (= 4.1.7)
                    activesupport (= 4.1.7)
                    rack (~> 1.5.2)
                    rack-test (~> 0.6.2)
                  actionview (4.1.7)
                    activesupport (= 4.1.7)
                    builder (~> 3.1)
                    erubis (~> 2.7.0)
                  activemodel (4.1.7)
                    activesupport (= 4.1.7)
                    builder (~> 3.1)
                  activesupport (4.1.7)
                    i18n (~> 0.6, >= 0.6.9)
                    json (~> 1.7, >= 1.7.7)
                    minitest (~> 5.1)
                    thread_safe (~> 0.1)
                    tzinfo (~> 1.1)
                  builder (3.2.2)
                  diff-lcs (1.2.5)
                  erubis (2.7.0)
                  i18n (0.6.11)
                  json (1.8.1)
                  minitest (5.4.3)
                  rack (1.5.2)
                  rack-test (0.6.2)
                    rack (>= 1.0)
                  railties (4.1.7)
                    actionpack (= 4.1.7)
                    activesupport (= 4.1.7)
                    rake (>= 0.8.7)
                    thor (>= 0.18.1, < 2.0)
                  rake (10.4.0)
                  rspec-core (2.14.8)
                  rspec-expectations (2.14.5)
                    diff-lcs (>= 1.1.3, < 2.0)
                  rspec-mocks (2.14.6)
                  rspec-rails (2.14.2)
                    actionpack (>= 3.0)
                    activemodel (>= 3.0)
                    activesupport (>= 3.0)
                    railties (>= 3.0)
                    rspec-core (~> 2.14.0)
                    rspec-expectations (~> 2.14.0)
                    rspec-mocks (~> 2.14.0)
                  thor (0.19.1)
                  thread_safe (0.3.4)
                  tzinfo (1.2.2)
                    thread_safe (~> 0.1)

              PLATFORMS
                ruby

              DEPENDENCIES
                rspec-rails (~> 2.14.0)
            END
          end

          it { should be_true }
        end

        context 'and rspec-rails is not bundled' do
          let(:gemfile_content) do
            <<-END.strip_heredoc
              GEM
                remote: https://rubygems.org/
                specs:
                  diff-lcs (1.2.5)
                  rspec (2.14.1)
                    rspec-core (~> 2.14.0)
                    rspec-expectations (~> 2.14.0)
                    rspec-mocks (~> 2.14.0)
                  rspec-core (2.14.8)
                  rspec-expectations (2.14.5)
                    diff-lcs (>= 1.1.3, < 2.0)
                  rspec-mocks (2.14.6)

              PLATFORMS
                ruby

              DEPENDENCIES
                rspec (~> 2.14.0)
            END
          end

          it { should be_false }
        end
      end

      context 'when the project have no Gemfile.lock' do
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

                Bundler.with_clean_env do
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

        it 'returns version of the RSpec installed in the system' do
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
