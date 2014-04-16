# coding: utf-8

require 'spec_helper'
require 'transpec'

module Transpec
  describe '.root' do
    it 'returns the path for project root directory' do
      Dir.chdir(Transpec.root) do
        File.should exist('Gemfile')
      end
    end
  end

  describe '.required_rspec_version' do
    subject { Transpec.required_rspec_version }

    it 'returns an instance of RSpecVersion' do
      should be_a(RSpecVersion)
    end
  end
end
