# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Localized

    class LocalizedDate < LocalizedDateTime
      LENGTHS.each do |length|
        define_method "to_#{length}_s" do |**options|
          options = chain_params.merge(options)
          pattern = patterns.date_pattern_for(length)
          TwitterCldr::Formatters::DateTimeFormatter.for(pattern).format(base_in_timezone, **chain_params, **options)
        end
      end

      alias :to_default_s :to_medium_s

      def to_datetime(time = Time.now)
        dt = DateTime.parse("#{base_obj.strftime("%Y-%m-%d")}T#{unwrap_time_obj(time).strftime("%H:%M:%S%z")}")
        LocalizedDateTime.new(dt, locale, chain_params)
      end

      def to_time(base = Time.now)
        case base_obj
          when Time
            LocalizedTime.new(base_obj, locale, chain_params)
          when Date, DateTime
            LocalizedTime.new(base_obj.to_time, locale, chain_params)
          else
            nil
        end
      end

      protected

      def unwrap_time_obj(time)
        time.is_a?(LocalizedTime) ? time.base_obj : time
      end

      def base_in_timezone
        time = unwrap_time_obj(to_time)
        timezone_info.utc_to_local(time.is_a?(DateTime) ? time.new_offset(0) : time.utc)
      end

    end
  end
end
