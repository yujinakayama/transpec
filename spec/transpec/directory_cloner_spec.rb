# coding: utf-8

require 'spec_helper'
require 'transpec/directory_cloner'

module Transpec
  describe DirectoryCloner do
    include FileHelper
    include_context 'isolated environment'

    describe '#copy_recursively' do
      it 'copies files recursively' do
        [
          'src/file1',
          'src/file2',
          'src/dir1/file',
          'src/dir2/file'
        ].each do |path|
          create_file(path, '')
        end

        DirectoryCloner.copy_recursively('src', 'dst')

        [
          'dst/file1',
          'dst/file2',
          'dst/dir1/file',
          'dst/dir2/file'
        ].each do |path|
          File.exist?(path).should be_true
        end
      end

      it 'copies only directories, files and symlinks' do
        create_file('src/file', '')
        File.symlink('file', 'src/symlink')
        Dir.mkdir('src/dir')
        system('mkfifo', 'src/fifo')

        DirectoryCloner.copy_recursively('src', 'dst')

        File.file?('dst/file').should be_true
        File.symlink?('dst/symlink').should be_true
        File.directory?('dst/dir').should be_true
        File.exist?('dst/fifo').should be_false
      end

      def permission(path)
        format('%o', File.lstat(path).mode)[-4..-1]
      end

      it 'preserves permission' do
        create_file('src/file', '')
        File.chmod(0755, 'src/file')

        File.symlink('file', 'src/symlink')

        Dir.mkdir('src/dir')
        File.chmod(0600, 'src/dir')

        DirectoryCloner.copy_recursively('src', 'dst')

        permission('dst/file').should == '0755'
        permission('dst/dir').should == '0600'
      end

      it 'returns the copied directory path' do
        Dir.mkdir('src')
        path = DirectoryCloner.copy_recursively('src', 'dst')
        path.should == File.expand_path('dst')
      end
    end
  end
end
