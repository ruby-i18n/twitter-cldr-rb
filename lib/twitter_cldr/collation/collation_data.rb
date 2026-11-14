# frozen_string_literal: true

module TwitterCldr
  module Collation
    class CollationData
      attr_reader :trie

      class << self
        def root
          @root ||= ChunkedCollationData.new(
            TwitterCldr.resources.absolute_resource_path(File.join("collation", "data", "root")), "root"
          )
        end

        def for_locale(locale)
          locale_cache[locale] ||= ChunkedCollationData.new(
            TwitterCldr.resources.absolute_resource_path(File.join("collation", "data", locale.to_s)), locale
          )
        end

        private

        def locale_cache
          @locale_cache ||= {}
        end
      end

      def initialize(**data)
        @trie = data[:trie]
        @context_data = data[:contexts]
      end

      def contexts
        @contexts ||= @context_data.each_with_object({}) do |(cp, data), memo|
          memo[cp] = Context.new(**data, suffixes: @trie[cp])
        end
      end
    end
  end
end
