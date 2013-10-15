# coding: utf-8

require 'spec_helper'
require 'transpec/file_finder'

module Transpec
  describe FileFinder do
    include FileHelper

    describe '.find' do
      include_context 'isolated environment'

      before do
        ['file', 'file.rb', 'dir/file', 'dir/file.rb'].each do |path|
          create_file(path, '')
        end
      end

      subject { FileFinder.find(paths) }

      context 'when no path is passed' do
        let(:paths) { [] }

        it 'returns empty array' do
          should be_empty
        end
      end

      context 'when a file path with .rb extension is passed' do
        let(:paths) { ['file.rb'] }

        it 'returns the path' do
          should == ['file.rb']
        end
      end

      context 'when a file path without extension is passed' do
        let(:paths) { ['file'] }

        it 'returns the path' do
          should == ['file']
        end
      end

      context 'when a non-existent path is passed' do
        let(:paths) { ['non-existent-file'] }

        it 'raises error' do
          -> { FileFinder.find(paths) }.should raise_error(ArgumentError) { |error|
            error.message.should == 'No such file or directory "non-existent-file"'
          }
        end
      end

      context 'when a directory path is passed' do
        let(:paths) { ['dir'] }

        it 'returns file paths with .rb extension in the directory recursively' do
          should == ['dir/file.rb']
        end
      end
    end
  end
end
