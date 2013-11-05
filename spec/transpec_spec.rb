# coding: utf-8

require 'spec_helper'
require 'transpec'

module Transpec
  [:required_rspec_version, :current_rspec_version].each do |method|
    describe ".#{method}" do
      subject { Transpec.send(method) }

      it 'returns an instance of RSpecVersion' do
        should be_a(RSpecVersion)
      end
    end
  end
end
