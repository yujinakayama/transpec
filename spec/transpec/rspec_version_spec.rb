# coding: utf-8

require 'spec_helper'
require 'transpec/rspec_version'

module Transpec
  describe RSpecVersion do
    subject(:rspec_version) { RSpecVersion.new(version_string) }

    describe '#be_truthy_available?' do
      subject { rspec_version.be_truthy_available? }

      [
        ['2.14.0',        false],
        ['2.99.0.beta.1', true],
        ['2.99.0',        true],
        ['3.0.0.beta.1',  true],
        ['3.0.0',         true]
      ].each do |version, expected|
        context "when the version is #{version}" do
          let(:version_string) { version }
          it { should == expected }
        end
      end
    end

    describe '#receive_messages_available?' do
      subject { rspec_version.receive_messages_available? }

      [
        ['2.14.0',        false],
        ['2.99.0.beta.1', false],
        ['2.99.0',        false],
        ['3.0.0.beta.1',  true],
        ['3.0.0',         true]
      ].each do |version, expected|
        context "when the version is #{version}" do
          let(:version_string) { version }
          it { should == expected }
        end
      end
    end
  end
end
