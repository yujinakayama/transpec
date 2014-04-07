# encoding: utf-8

require 'digest/sha1'

module CacheHelper
  module_function

  def with_cache(key)
    cache_file_path = cache_file_path(key)

    if File.exist?(cache_file_path)
      load_cache(cache_file_path)
    else
      data = yield
      save_cache(cache_file_path, data)
      data
    end
  end

  def with_cached_dir(dirname)
    dir_path = File.join(cache_dir, dirname)

    cached = Dir.exist?(dir_path)
    FileUtils.mkdir_p(dir_path) unless cached

    Dir.chdir(dir_path) do
      yield cached
    end
  end

  def load_cache(path)
    File.open(path) do |file|
      Marshal.load(file)
    end
  end

  def save_cache(path, data)
    File.open(path, 'w') do |file|
      Marshal.dump(data, file)
    end
  end

  def cache_file_path(key)
    filename = Digest::SHA1.hexdigest(key)
    File.join(cache_dir, filename)
  end

  def cache_dir
    @cache_dir ||= begin
      project_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
      ruby_version = [RUBY_ENGINE, RUBY_VERSION].join('-')
      cache_dir = File.join(project_root, '.cache', 'spec', ruby_version)

      unless Dir.exist?(cache_dir)
        require 'fileutils'
        FileUtils.mkdir_p(cache_dir)
      end

      cache_dir
    end
  end
end
