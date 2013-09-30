# coding: utf-8

desc 'Generate README.md'
task :readme do
  require 'erb'
  require 'transpec/cli'

  gem_specification = Gem::Specification.load('transpec.gemspec')
  rspec_dependency = gem_specification.dependencies.find { |d| d.name == 'rspec' }
  rspec_requirement = rspec_dependency.requirement
  # rubocop:disable UselessAssignment
  rspec_version = rspec_requirement.requirements.first.find { |r| r.is_a?(Gem::Version) }
  # rubocop:enable UselessAssignment

  erb = ERB.new(File.read('README.md.erb'), nil, '-')
  content = erb.result(binding)
  File.write('README.md', content)
end
