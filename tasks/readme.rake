# coding: utf-8

desc 'Generate README.md'
task :readme do
  File.write('README.md', generate_readme)
end

namespace :readme do
  task :check do
    unless File.read('README.md') == generate_readme
      fail <<-END.gsub(/^\s+\|/, '').chomp
        |README.md and README.md.erb are out of sync!
        |If you need to modify the content of README.md:
        |  * Edit README.md.erb.
        |  * Run `bundle exec rake readme`.
        |  * Commit both files.
      END
    end
  end
end

def generate_readme
  require 'erb'
  require 'transpec/cli'

  erb = ERB.new(File.read('README.md.erb'), nil, '-')
  erb.result(binding)
end
