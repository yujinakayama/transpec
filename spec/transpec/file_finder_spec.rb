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

        context 'and there is "spec" directory' do
          before do
            create_file('spec/file.rb', '')
          end

          it 'returns file paths with .rb extension in the "spec" directory recursively' do
            should == ['spec/file.rb']
          end
        end

        context 'and there is not "spec" directory' do
          it 'raises error' do
            -> { FileFinder.find(paths) }.should raise_error(ArgumentError)
          end
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

    describe '.base_paths' do
      include_context 'isolated environment'

      subject { FileFinder.base_paths(paths) }

      context 'when target paths are specified' do
        let(:paths) { ['foo_spec.rb', 'spec/bar_spec.rb'] }

        it 'returns the passed paths' do
          should == paths
        end
      end

      context 'when paths outside of the current working directory are specified' do
        let(:paths) { ['../foo_spec.rb', 'spec/bar_spec.rb'] }

        it 'raises error' do
          -> { FileFinder.base_paths(paths) }.should raise_error(ArgumentError)
        end
      end

      context 'when no target paths are specified' do
        let(:paths) { [] }

        context 'and there is "spec" directory' do
          before do
            Dir.mkdir('spec')
          end

          it 'returns ["spec"]' do
            should == ['spec']
          end
        end

        context 'and there is not "spec" directory' do
          it 'raises error' do
            -> { FileFinder.base_paths(paths) }.should raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
