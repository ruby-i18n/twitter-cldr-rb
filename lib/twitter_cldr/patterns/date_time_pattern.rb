# frozen_string_literal: true

module TwitterCldr
  module Patterns
    class DateTimePattern
      attr_reader :locale, :calendar_type, :tokens

      def initialize(locale, calendar_type, tokens)
        @locale = locale
        @calendar_type = calendar_type
        @tokens = tokens
      end

      def format(*args, **kwargs)
        formatter.format(*args, **kwargs)
      end

      private

      def formatter
        @formatter ||= TwitterCldr::Formatters::DateTimeFormatter.new(self)
      end
    end
  end
end
