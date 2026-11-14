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

      # Compares two strings.
      #
      # If left > right, returns 1
      # If left < right, returns -1
      # If left == right, returns 0
      #
      # Options can include:
      #   - maximum_level: <number>, defaults to 3. The maximum collation level to generate the key for. Collation
      #     can be done at multiple levels: primary (1), secondary (2), tertiary (3), and quaternary (4). Each level
      #     is used for different purposes. See the Unicode Collation Algorithm (UCA) docs for more info.
      def compare(left_str, right_str, **options)
        return 0 if left_str == right_str

        left = TwitterCldr::Collation::CollationElementIterator.new(locale, left_str)
        right = TwitterCldr::Collation::CollationElementIterator.new(locale, right_str)

        comparator.compare(left, right, **options)
      end

      # Returns the sort key for a string. The sort key can be compared to other sort keys using Ruby's <=> method.
      # Eg. sort_key_for("abc") <=> sort_key_for("def") returns -1, since abc < def.
      #
      # Options can include:
      #   - maximum_level: <number>, defaults to 3. The maximum collation level to generate the key for. Collation
      #     can be done at multiple levels: primary (1), secondary (2), tertiary (3), and quaternary (4). Each level
      #     is used for different purposes. See the Unicode Collation Algorithm (UCA) docs for more info.
      #
      def sort_key_for(str, **options)
        iterator = TwitterCldr::Collation::CollationElementIterator.new(locale, str)
        TwitterCldr::Collation::SortKeyWriter.new(locale, iterator, **options).sort_key
      end

      # Returns an enumerator that yields the individual collation elements that the given string resolves to.
      def each_collation_element(str, &block)
        enumerator.each_collation_element(str, &block)
      end

      # Sorts an array of strings and returns a new array.
      def sort(strings)
        strings.sort do |first, second|
          compare(first, second)
        end
      end

      # Sorts an array of strings in place.
      def sort!(strings)
        strings.sort! do |first, second|
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
