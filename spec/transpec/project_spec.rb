# coding: utf-8

require 'spec_helper'
require 'transpec/project'

module Transpec
  describe Project do
    include FileHelper
    include_context 'isolated environment'

    subject(:project) { Project.new }

    describe '#require_bundler?' do
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
  end
end
