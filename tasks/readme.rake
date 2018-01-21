# coding: utf-8

require 'transpec'

desc 'Generate README.md'
task :readme do
  puts 'Generating README.md...'
  File.write('README.md', generate_readme)
  puts 'Done.'
end

namespace :readme do
  task :check do
    puts 'Checking README.md...'

    unless File.read('README.md') == generate_readme
      fail <<-END.gsub(/^\s+\|/, '').chomp
        |README.md and README.md.erb are out of sync!
        |If you need to modify the content of README.md:
        |  * Edit README.md.erb.
        |  * Run `bundle exec rake readme`.
        |  * Commit both files.
      END
    end

    puts 'Done.'
  end
end

def generate_readme
  require 'erb'
  readme = File.read('README.md.erb')
  erb = ERB.new(readme, nil, '-')
  erb.result(READMEContext.new(readme).binding)
end

class READMEContext
  include Transpec

  attr_reader :readme

  def initialize(readme)
    @readme = readme
  end

  def binding
    super
  end

  module SourceConversion
    def convert(source, options = {}) # rubocop:disable MethodLength
      require 'transpec/cli'
      require File.join(Transpec.root, 'spec/support/file_helper')

      cli_args = Array(options[:cli])
      cli_args << '--skip-dynamic-analysis' unless options[:dynamic] # For performance

      hidden_code = options[:hidden]
      if hidden_code
        hidden_code += "\n"
        source = hidden_code + source
      end

      source = wrap_source(source, options[:wrap_with])

      converted_source = nil

      in_isolated_env do
        path = options[:path] || 'spec/example_spec.rb'
        FileHelper.create_file(path, source)

        cli = Transpec::CLI.new

        if options[:rspec_version]
          cli.project.define_singleton_method(:rspec_version) { options[:rspec_version] }
        end

        if options[:rails]
          cli.project.define_singleton_method(:depend_on_rspec_rails?) { true }
        end

        cli.run(cli_args)

        converted_source = File.read(path)
      end

      converted_source = unwrap_source(converted_source, options[:wrap_with])
      converted_source = converted_source[hidden_code.length..-1] if hidden_code
      converted_source
    end

    def wrap_source(source, wrapper)
      source = "it 'is example' do\n" + source + "end\n" if wrapper == :example

      if [:example, :group].include?(wrapper)
        source = "describe 'example group' do\n" + source + "end\n"
      end

      source
    end

    def unwrap_source(source, wrapper)
      return source unless wrapper

      unwrap_count = case wrapper
                     when :group then 1
                     when :example then 2
                     end

      lines = source.lines.to_a

      unwrap_count.times do
        lines = lines[1..-2]
      end

      lines.join('')
    end

    def in_isolated_env
      require 'stringio'
      require 'tmpdir'

      original_stdout = $stdout
      $stdout = StringIO.new

      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          yield
        end
      end
    ensure
      $stdout = original_stdout
    end
  end

  include SourceConversion

  module MarkdownHelper
    def find_section(section_name, options = {})
      header_pattern = pattern_for_header_level(options[:level])
      sections = readme.each_line.slice_before(header_pattern)

      sections.find do |section|
        header_line = section.first
        header_line.include?(section_name)
      end
    end

    def table_of_contents(lines, options = {})
      header_pattern = pattern_for_header_level(options[:level])

      titles = lines.map do |line|
        next unless line.match(header_pattern)
        line.sub(/^[#\s]*/, '').chomp
      end.compact

      titles.map do |title|
        anchor = '#' + title.gsub(/[^\w_\- ]/, '').downcase.tr(' ', '-')
        "* [#{title}](#{anchor})"
      end.join("\n")
    end

    def pattern_for_header_level(level)
      /^#{'#' * level}[^#]/
    end
  end

  include MarkdownHelper

  module SyntaxTypeTableHelper
    def validate_syntax_type_table(markdown_table, enabled_by_default)
      types_in_doc = markdown_table.lines.map do |line|
        first_column = line.split('|').first
        first_column.gsub(/[^\w]/, '').to_sym
      end.sort

      types_in_code = Transpec::Config::DEFAULT_CONVERSIONS.select do |_type, enabled|
        enabled == enabled_by_default
      end.keys.sort

      unless types_in_doc == types_in_code
        types_missing_description = types_in_code - types_in_doc
        fail "No descriptions for syntax types #{types_missing_description}"
      end
    end
  end

  include SyntaxTypeTableHelper

  module CodeExampleHelper
    def insert_comment_above(code, pattern, comments)
      regexp = Regexp.new('^([ \t]*).*' + Regexp.escape(pattern))

      code.sub(regexp) do |match|
        indentation = Regexp.last_match(1)
        replacement = ''
        Array(comments).each do |comment|
          comment = comment.to_s.chomp
          replacement << "#{indentation}# #{comment}\n"
        end
        replacement << match
      end
    end
  end

  include CodeExampleHelper

  module SupportedRubyListHelper
    def supported_ruby_names
      supported_ruby_ids.map { |id| ruby_name_from(id) }
    end

    def ruby_name_from(id)
      implementation, version = id.split('-', 2)

      if implementation == 'jruby'
        implementation = 'JRuby'
      elsif version.nil?
        version = implementation
        implementation = 'MRI'
      end

      "#{implementation} #{version}"
    end

    def supported_ruby_ids
      travis_config['rvm'] - unsupported_ruby_ids
    end

    def unsupported_ruby_ids
      return [] unless travis_config['matrix']
      travis_config['matrix']['allow_failures'].map { |build| build['rvm'] }.compact
    end

    def travis_config
      @travis_config ||= begin
        require 'yaml'
        YAML.parse_file('.travis.yml').to_ruby
      end
    end
  end

  include SupportedRubyListHelper
end
