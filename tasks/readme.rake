# coding: utf-8

desc 'Generate README.md'
task :readme do
  require 'erb'
  require 'transpec/cli'

  erb = ERB.new(File.read('README.md.erb'), nil, '-')
  content = erb.result(binding)
  File.write('README.md', content)
end
