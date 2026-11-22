# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Localized

    class LocalizedTime < LocalizedDateTime
      LENGTHS.each do |length|
        define_method "to_#{length}_s" do |**options|
          options = chain_params.merge(options)
          pattern = patterns.time_pattern_for(length)
          TwitterCldr::Formatters::DateTimeFormatter.for(pattern).format(base_in_timezone, **chain_params, **options)
        end
      end

      alias :to_default_s :to_medium_s

      def to_datetime(date)
        date_obj = date.is_a?(LocalizedDate) ? date.base_obj : date
        dt = DateTime.parse("#{date_obj.strftime("%Y-%m-%d")}T#{base_obj.strftime("%H:%M:%S%z")}")
        LocalizedDateTime.new(dt, locale, chain_params)
      end

      def to_time(base_time = Time.now)
        self
      end

      def to_date
        LocalizedDate.new(base_obj, locale, chain_params)
      end

      def gmtime
        LocalizedTime.new(base_obj.gmtime, locale, chain_params)
      end

      def localtime
        LocalizedTime.new(base_obj.localtime, locale, chain_params)
      end

      protected

      def base_in_timezone
        timezone_info.utc_to_local(base_obj.utc)
      end
    end

  end
end
