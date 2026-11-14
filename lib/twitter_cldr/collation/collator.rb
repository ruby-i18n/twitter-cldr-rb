# frozen_string_literal: true

module TwitterCldr
  module Collation
    class Collator
      class << self
        def for(locale)
          cache[locale] ||= new(locale)
        end

        private

        def cache
          @cache ||= {}
        end
      end

      attr_reader :locale

      def initialize(locale)
        @locale = locale == :root ? locale : TwitterCldr.normalize_locale(locale)
      end

      def compare(left_str, right_str, **options)
        left = TwitterCldr::Collation::CollationElementIterator.new(locale, left_str)
        right = TwitterCldr::Collation::CollationElementIterator.new(locale, right_str)
        comparator.compare(left, right, **options)
      end

      def sort_key_for(str, **options)
        iterator = TwitterCldr::Collation::CollationElementIterator.new(locale, str)
        TwitterCldr::Collation::SortKeyWriter.new(locale, iterator, **options).sort_key
      end

      # Legacy method to maintain older API
      def get_sort_key(string_or_code_points, options = {})
        string = if string_or_code_points.is_a?(Array)
          string_or_code_points.pack("U*")
        else
          string_or_code_points
        end

        sort_key_for(string, **options)
      end

      def each_collation_element(str, &block)
        enumerator.each_collation_element(str, &block)
      end

      # Legacy method to maintain older API
      def get_collation_elements(string_or_code_points)
        string = if string_or_code_points.is_a?(Array)
          string_or_code_points.pack("U*")
        else
          string_or_code_points
        end

        each_collation_element(string).to_a
      end

      def sort(strings)
        strings.sort do |first, second|
          compare(first, second)
        end
      end

      def sort!(strings)
        strings.sort do |first, second|
          compare(first, second)
        end
      end

      private

      def comparator
        @comparator ||= TwitterCldr::Collation::CollationComparator.for(locale)
      end

      def enumerator
        @enumerator ||= TwitterCldr::Collation::CollationElementEnumerator.for(locale)
      end
    end
  end
end
