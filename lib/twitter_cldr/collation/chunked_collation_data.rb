# frozen_string_literal: true

require "zlib"

module TwitterCldr
  module Collation
    class ChunkedCollationData
      attr_reader :path, :locale

      def initialize(path, locale)
        @path = path
        @locale = locale
      end

      def suffixes_for(cp)
        cached_suffixes_for(cp) do
          collation_data = collation_data_for(cp)
          return unless collation_data

          collation_data.trie[cp]
        end
      end

      def context_for(cp)
        cached_context_for(cp) do
          collation_data = collation_data_for(cp)
          return unless collation_data

          collation_data.contexts[cp]
        end
      end

      private

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

      def collation_data_for(cp)
        collation_data_cache.fetch(cp) do
          block_range = block_range_for(cp)

          if !block_range
            collation_data_cache[cp] = nil
            return
          end

          collation_data_cache[cp] = block_collation_data_for(block_range)
        end
      end

      def collation_data_cache
        @collation_data_cache ||= {}
      end

      def block_collation_data_for(block_range)
        block_collation_data_cache.fetch(block_range) do
          data_path = block_range_map[block_range]
          block_collation_data_cache[block_range] = CollationData.new(
            **Marshal.load(
              Zlib::Inflate.inflate(File.binread(data_path))
            )
          )
        end
      end

      def block_collation_data_cache
        @block_collation_data_cache ||= {}
      end

      def block_range_for(cp)
        block_range_cache.fetch(cp) do
          block_range_cache[cp] = block_ranges.bsearch do |range|
            next -1 if cp < range.begin
            next 1 if cp > range.end
            0
          end
        end
      end

      def block_range_cache
        @block_range_cache ||= {}
      end

      def block_ranges
        @block_ranges ||= block_range_map.keys.sort_by(&:begin)
      end

      def block_range_map
        @block_range_map ||= Dir.glob(File.join(path, "*.dump")).each_with_object({}) do |path, memo|
          start, stop = File.basename(path).chomp(".dump").split("-").map(&:to_i)
          memo[start..stop] = path
        end
      end
    end
  end
end
