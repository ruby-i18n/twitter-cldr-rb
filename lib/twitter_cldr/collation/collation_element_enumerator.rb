# frozen_string_literal: true

module TwitterCldr
  module Collation
    class CollationElementEnumerator
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

      def initialize(locale = TwitterCldr.locale, str)
        @locale = locale == :root ? locale : TwitterCldr.normalize_locale(locale)
      end

      def each_collation_element(str)
        return to_enum(__method__, str) unless block_given?

        iterator = CollationElementIterator.new(locale, str)

        while iterator.next_ce?
          yield iterator.next_ce
        end
      end
    end
  end
end
