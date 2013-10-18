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
      spec_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
      cache_dir = File.join(spec_dir, 'cache')

      unless Dir.exist?(cache_dir)
        require 'fileutils'
        FileUtils.mkdir_p(cache_dir)
      end

      cache_dir
    end
  end
end
