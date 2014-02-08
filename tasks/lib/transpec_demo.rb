# coding: utf-8

require_relative 'transpec_test'

class TranspecDemo < TranspecTest
  DEMO_BRANCH = 'transpec-demo'

  def self.base_dir_path
    @base_dir_path = File.join('tmp', 'demos')
  end

  def run
    require 'transpec'

    puts " Running demo on #{name} project ".center(80, '=')

    prepare_project
    run_demo
  end

  private

  def prepare_with_git_repo
    super
    git_branch_delete(DEMO_BRANCH) if git_local_branch_exist?(DEMO_BRANCH)
  end

  def run_demo(transpec_args = [])
    in_project_dir do
      with_clean_bundler_env do
        sh File.join(Transpec.root, 'bin', 'transpec'), '--force', '--convert-stub-with-hash'
        sh 'bundle exec rspec'
        sh "git checkout --quiet -b #{DEMO_BRANCH}"
        sh 'git commit --all --file .git/COMMIT_EDITMSG'
        sh "git push --force origin #{DEMO_BRANCH}"
      end
    end
  end

  def git_local_branch_exist?(branch_name)
    in_project_dir do
      system('git', 'show-ref', '--verify', '--quiet', "refs/heads/#{branch_name}")
    end
  end

  def git_branch_delete(branch_name)
    in_project_dir do
      sh "git branch -D #{branch_name}"
    end
  end
end
