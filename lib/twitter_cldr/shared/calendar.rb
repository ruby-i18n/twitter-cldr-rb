# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Shared
    class Calendar

      DEFAULT_FORMAT = :format

      NAMES_FORMS = [:wide, :narrow, :short, :abbreviated]
      ERAS_NAMES_FORMS = [:abbr, :name]

      DATETIME_METHOD_MAP = {
        year_of_week_of_year: :year,
        quarter_stand_alone: :quarter,
        month_stand_alone: :month,
        day_of_month: :day,
        day_of_week_in_month: :day,
        weekday_local: :weekday,
        weekday_local_stand_alone: :weekday,
        second_fraction: :second,
        timezone_generic_non_location: :timezone,
        timezone_metazone: :timezone
      }

      attr_reader :locale, :calendar_type

      def initialize(locale = TwitterCldr.locale, calendar_type = TwitterCldr::DEFAULT_CALENDAR_TYPE)
        @locale = TwitterCldr.normalize_locale(locale)
        @calendar_type = calendar_type
      end

      def months(names_form = :wide, format = DEFAULT_FORMAT)
        cache_field_data(:months, names_form, format) do
          data = get_with_names_form(:months, names_form, format)
          data && data.sort_by { |m| m.first }.map { |m| m.last }
        end
      end

      def weekdays(names_form = :wide, format = DEFAULT_FORMAT)
        cache_field_data(:weekdays, names_form, format) do
          get_with_names_form(:days, names_form, format)
        end
      end

      def fields
        cache_field_data(:fields) do
          get_data(:fields)
        end
      end

      def quarters(names_form = :wide, format = DEFAULT_FORMAT)
        cache_field_data(:quarters, names_form, format) do
          get_with_names_form(:quarters, names_form, format)
        end
      end

      def periods(names_form = :wide, format = DEFAULT_FORMAT)
        cache_field_data(:periods, names_form, format) do
          get_with_names_form(:periods, names_form, format)
        end
      end

      def eras(names_form = :name)
        cache_field_data(:eras, names_form) do
          get_data(:eras)[names_form]
        end
      end

      def date_order(length: :medium, format_type: :standard)
        pattern = patterns.date_pattern_for(length, format_type: format_type)
        resolve_methods(methods_for_tokens(pattern.tokens))
      end

      def time_order(length: :medium, format_type: :standard)
        pattern = patterns.time_pattern_for(length, format_type: format_type)
        resolve_methods(methods_for_tokens(pattern.tokens))
      end

      def datetime_order(date_length: :medium, time_length: :medium, format_type: :standard)
        pattern = patterns.datetime_pattern_for(:medium, date_length: date_length, time_length: time_length, format_type: format_type)
        resolve_methods(methods_for_tokens(pattern.tokens))
      end

      def calendar_data
        @calendar_data ||= TwitterCldr::Utils.traverse_hash(resource, [locale, :calendars, calendar_type])
      end

      private

      def cache_field_data(field, names_form = nil, format = nil)
        cache_key = TwitterCldr::Utils.compute_cache_key(locale, field, names_form, format)
        field_cache[cache_key] ||= begin
          yield
        end
      end

      def field_cache
        @@field_cache ||= {}
      end

      def calendar_cache
        @@calendar_cache ||= {}
      end

      def day_periods_cache
        @@day_periods_cache ||= {}
      end

      def resolve_methods(methods)
        methods.map { |method| DATETIME_METHOD_MAP.fetch(method, method) }
      end

      def methods_for_tokens(tokens)
        tokens.each_with_object([]) do |token, memo|
          case token.type
            when :date_pattern, :time_pattern
              memo << TwitterCldr::Formatters::DateTimeFormatter::PATTERN_MAP[token.value[0].chr]
          end
        end
      end

      def get_with_names_form(data_type, names_form, format)
        get_data(data_type, format, names_form) if NAMES_FORMS.include?(names_form.to_sym)
      end

      def get_data(*path)
        cache_key = TwitterCldr::Utils.compute_cache_key([@locale] + path)
        calendar_cache.fetch(cache_key) do |key|
          data = TwitterCldr::Utils.traverse_hash(calendar_data, path)
          calendar_cache[key] = data
        end
      end

      def patterns
        @patterns ||= TwitterCldr::Patterns::DateTimePatterns.for(locale, calendar_type)
      end

      def resource
        @resource ||= TwitterCldr.get_locale_resource(locale, :calendars)
      end

    end
  end
end
