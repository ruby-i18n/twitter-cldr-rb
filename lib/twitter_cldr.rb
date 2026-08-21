# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'yaml'
require 'date'
require 'time'
require 'fileutils'

require 'forwardable'

require 'twitter_cldr/version'
require 'twitter_cldr/supported_locales'

Enumerator = Enumerable::Enumerator unless defined?(Enumerator)

module TwitterCldr

  autoload :Collation,     'twitter_cldr/collation'
  autoload :DataReaders,   'twitter_cldr/data_readers'
  autoload :Formatters,    'twitter_cldr/formatters'
  autoload :Localized,     'twitter_cldr/localized'
  autoload :Normalization, 'twitter_cldr/normalization'
  autoload :Parsers,       'twitter_cldr/parsers'
  autoload :Resources,     'twitter_cldr/resources'
  autoload :Segmentation,  'twitter_cldr/segmentation'
  autoload :Shared,        'twitter_cldr/shared'
  autoload :Tokenizers,    'twitter_cldr/tokenizers'
  autoload :Utils,         'twitter_cldr/utils'
  autoload :Timezones,     'twitter_cldr/timezones'
  autoload :Transforms,    'twitter_cldr/transforms'
  autoload :Versions,      'twitter_cldr/versions'

  extend SingleForwardable

  DEFAULT_LOCALE = :en
  DEFAULT_CALENDAR_TYPE = :gregorian

  RESOURCES_DIR = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'resources')
  VENDOR_DIR = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'vendor')
  LIB_DIR = File.dirname(File.expand_path(__FILE__))
  SPEC_DIR = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'spec')

  def_delegator :resources, :get_resource
  def_delegator :resources, :get_locale_resource
  def_delegator :resources, :resource_exists?
  def_delegator :resources, :locale_resource_exists?
  def_delegator :resources, :absolute_resource_path
  def_delegator :resources, :resource_file_path

  class UnsupportedLocaleError < StandardError
  end

  class << self

    attr_reader :locale
    attr_accessor :disable_custom_locale_resources

    def resources
      @resources ||= TwitterCldr::Resources::Loader.new
    end

    def locale
      return @locale if @locale

      if defined?(I18n) && I18n.respond_to?(:locale)
        return normalize_locale(I18n.locale)
      end

      DEFAULT_LOCALE
    end

    def locale=(new_locale)
      @locale = normalize_locale(new_locale)
    end

    def with_locale(locale)
      locale = normalize_locale(locale)

      begin
        old_locale = @locale
        @locale = locale
        yield
      ensure
        @locale = old_locale
      end
    end

    def normalize_locale(obj)
      normalized_locale_map[obj] ||= begin
        # allow setting locale to nil
        return obj if obj.nil?

        locale = case obj
          when String, Symbol
            loc = obj.to_sym
            loc = lowercase_locales_map.fetch(loc, loc)
            TwitterCldr::Shared::Locale.parse(loc)
          when TwitterCldr::Shared::Locale
            obj
        end

        supported = locale&.supported

        if locale&.dasherized == 'und' || !supported
          raise UnsupportedLocaleError, "'#{obj.inspect}' is not a supported locale"
        end

        supported.dasherized.to_sym
      end
    end

    def supported_locales
      TwitterCldr::SUPPORTED_LOCALES
    end

    def supported_locale?(locale)
      return false unless locale

      begin
        locale = normalize_locale(locale)
      rescue UnsupportedLocaleError
        return false
      end

      supported_locales.include?(locale)
    end

    protected

    def lowercase_locales_map
      @lowercase_locales_map ||= supported_locales.inject({}) do |memo, locale|
        lowercase = locale.to_s.downcase.to_sym
        memo[lowercase] = locale unless lowercase == locale
        memo
      end
    end

    def normalized_locale_map
      @normalized_locale_map ||= {}
    end

  end

end

require 'twitter_cldr/core_ext'
