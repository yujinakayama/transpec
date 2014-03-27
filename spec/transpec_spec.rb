# coding: utf-8

require 'spec_helper'
require 'transpec'

module Transpec
  describe '.required_rspec_version' do
    subject { Transpec.required_rspec_version }

    it 'returns an instance of RSpecVersion' do
      should be_a(RSpecVersion)
    end
  end
end
