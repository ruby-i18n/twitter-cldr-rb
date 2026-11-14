# frozen_string_literal: true

require "zlib"

module TwitterCldr
  module Collation
    class TailoredCollationData
      class << self
        def for_locale(locale = TwitterCldr.locale)
          cache[locale] ||= begin
            if locale == :root
              new(:root, [:root])
            else
              locale = TwitterCldr.normalize_locale(locale)
              ancestor_chain = TwitterCldr::Shared::Locale.parse(locale).ancestor_chain
              new(locale, ancestor_chain.map(&:dasherized))
            end
          end
        end

        private :new

        private

        def cache
          @cache ||= {}
        end
      end

      attr_reader :locale, :ancestor_chain

      def initialize(locale, ancestor_chain)
        @locale = locale
        @ancestor_chain = ancestor_chain
      end

      def suffixes_for(cp)
        cached_suffixes_for(cp) do
          suffixes = nil

          data_sources.each do |data_source|
            suffixes = data_source.suffixes_for(cp)
            break if suffixes
          end

          suffixes
        end
      end

      def context_for(cp)
        cached_context_for(cp) do
          context = nil

          data_sources.each do |data_source|
            context = data_source.context_for(cp)
            break if context
          end

          context
        end
      end

      def settings
        @settings ||= CollationSettings.new(**metadata[:settings])
      end

      def compressible_bytes
        metadata[:compressible_bytes]
      end

      private

      def metadata
        @metadata ||= begin
          path = TwitterCldr.resources.absolute_resource_path(File.join("collation", "data", "#{locale}.dump"))
          Marshal.load(Zlib::Inflate.inflate(File.binread(path)))
        end
      end

      def cached_suffixes_for(cp)
        suffix_cache.fetch(cp) do
          suffix_cache[cp] = yield
        end
      end

      def suffix_cache
        @suffix_cache ||= {}
      end

      def cached_context_for(cp)
        context_cache.fetch(cp) do
          context_cache[cp] = yield
        end
      end

      def context_cache
        @context_cache ||= {}
      end

      def data_sources
        # ancestor_chain should include :root
        @data_sources ||= [
          *ancestor_chain.map do |ancestor_locale|
            CollationData.for_locale(ancestor_locale)
          end,

          CollationData.root,
        ]
      end
    end
  end
end
