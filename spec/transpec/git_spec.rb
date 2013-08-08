# coding: utf-8

require 'spec_helper'

module Transpec
  describe Git do
    include_context 'isolated environment'

    describe '.command_available?' do
      subject { Git.command_available? }

      context 'when git command is found in PATH' do
        it { should be_true }
      end

      context 'when git command is not found in PATH' do
        before { stub_const('Transpec::Git::GIT', 'non-existent-command') }
        it { should be_false }
      end
    end

    shared_context 'inside of git repository' do
      around do |example|
        Dir.mkdir('repo')
        Dir.chdir('repo') do
          `git init`
          example.run
        end
      end
    end

    describe '.inside_of_repository?' do
      subject { Git.inside_of_repository? }

      context 'when the current directory is inside of git repository' do
        include_context 'inside of git repository'
        it { should be_true }
      end

      context 'when the current directory is not inside of git repository' do
        it { should be_false }
      end
    end

    describe '.clean?' do
      include_context 'inside of git repository'

      subject { Git.clean? }

      before do
        File.write('foo', 'This is a sample file')
        `git add .`
        `git commit -m 'Initial commit'`
      end

      context 'when there are no changes' do
        it { should be_true }
      end

      context 'when there is an untracked file' do
        before { File.write('bar', 'This is an untracked file') }
        it { should be_false }
      end

      context 'when there is a deleted file' do
        before { File.delete('foo') }
        it { should be_false }
      end

      context 'when there is a not staged change' do
        before { File.write('foo', 'This is modified content') }
        it { should be_false }
      end

      context 'when there is a staged change' do
        before do
          File.write('foo', 'This is modified content')
          `git add .`
        end

        it { should be_false }
      end
    end
  end
end
