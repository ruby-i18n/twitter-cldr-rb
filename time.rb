# encoding: UTF-8

require "twitter_cldr"

module TwitterCldr
  module Patterns
    class UnsupportedPatternError < StandardError
    end

    class DateTimePatterns
      FIELD_TO_CATEGORY_MAP = {
        'G' => :era,
        'y' => :year,
        'Y' => :year,
        'q' => :quarter,
        'Q' => :quarter,
        'M' => :month,
        'L' => :month,
        'w' => :week,
        'W' => :week,
        'd' => :day,
        'D' => :day,
        'E' => :day_of_week,
        'e' => :day_of_week,
        'c' => :day_of_week,
        'F' => :day_of_week,
        'h' => :hour,
        'H' => :hour,
        'K' => :hour,
        'k' => :hour,
        'm' => :minute,
        's' => :second,
        'S' => :second_fraction,
        'a' => :period,
        'B' => :period,
        'z' => :timezone,
        'Z' => :timezone,
        'O' => :timezone,
        'v' => :timezone,
        'V' => :timezone,
        'X' => :timezone,
        'x' => :timezone
      }.freeze

      APPEND_ITEM_CATEGORY_TO_CALENDAR_FIELD_MAP = {
        day_of_week: :weekday,
        timezone: :zone
      }.freeze

      NON_ADJUST_TYPES = [:hour, :minute, :second].freeze

      class << self
        def get(locale, calendar_type = TwitterCldr::DEFAULT_CALENDAR_TYPE)
          locale = TwitterCldr::Shared::Locale.parse(locale)
          region = locale.region || TwitterCldr::Shared::LikelySubtags.for_locale(locale).region

          locale = TwitterCldr.normalize_locale(locale)
          calendar_type = calendar_type.to_sym
          cache_key = "#{locale}-#{region}-#{calendar_type}"

          if (instance = cache[cache_key])
            return instance
          end

          if (resource = resource_for(locale, calendar_type))
            return cache[cache_key] = new(locale, region, calendar_type, resource)
          end

          raise UnsupportedPatternError, "Could not find datetime pattern for locale #{locale.inspect} and "\
            "calendar type #{calendar_type.inspect}"
        end

        private :new

        private

        def cache
          @cache ||= {}
        end

        def resource_for(locale, calendar_type)
          TwitterCldr.get_locale_resource(locale, :calendars).dig(locale, :calendars, calendar_type)
        end
      end

      attr_reader :locale, :region, :calendar_type, :resource

      def date_pattern_for(length)
        pattern_for(:date, :standard, length)
      end

      def time_pattern_for(length)
        pattern_for(:time, :standard, length)
      end

      def datetime_pattern_for(length, format_type: :standard, date_length: length, time_length: length)
        cache_key = "datetime-#{length}-#{format_type}-#{date_length}-#{time_length}"

        if (pattern = pattern_cache[cache_key])
          return pattern
        end

        tokens = pattern_for(:datetime, format_type, length).tokens.flat_map do |token|
          case token.type
            when :date_placeholder
              date_pattern_for(date_length).tokens
            when :time_placeholder
              time_pattern_for(time_length).tokens
            else
              token
          end
        end

        pattern_cache[cache_key] = DateTimePattern.new(locale, calendar_type, tokens)
      end

      def pattern_for(object_type, format_type, length)
        cache_key = "#{object_type}-#{format_type}-#{length}"

        if (pattern = pattern_cache[cache_key])
          return pattern
        end

        pattern_str = resource.dig(:formats, object_type, length, format_type, :pattern)

        unless pattern_str
          raise UnsupportedPatternError, "Could not find datetime pattern for object #{object_type.inspect}, "\
            "format #{format_type.inspect}, and length #{length.inspect}"
        end

        tokens = tokenize(pattern_str)
        pattern_cache[cache_key] = DateTimePattern.new(locale, calendar_type, tokens)
      end

      def additional_pattern_for(skeleton)
        pattern = find_additional_pattern_for(skeleton.to_s)
        return pattern if pattern

        raise UnsupportedPatternError, "Could not find additional datetime pattern for ID #{skeleton.inspect}"
      end

      private

      def initialize(locale, region, calendar_type, resource)
        @locale = locale
        @region = region
        @calendar_type = calendar_type
        @resource = resource
      end

      def additional_formats
        @additional_formats ||= resource[:additional_formats].merge(
          resource[:formats].each_with_object({}) do |(_, lengths), memo|
            lengths.each_pair do |_, formats|
              formats.each_pair do |_, format|
                if format.include?(:skeleton)
                  memo[format[:skeleton].to_sym] = format[:pattern]
                end
              end
            end
          end
        )
      end

      def additional_format_skeletons
        @additional_format_skeletons ||= additional_formats.keys.map(&:to_s)
      end

      def append_items
        resource[:append_items]
      end

      # The algorithm here works like this:
      #
      # 1. Try to find a matching skeleton with all the same fields (not necessarily the same length)
      #    a. If a so-called "exact" match is found, adjust the lengths to match the input skeleton
      #       (following certain rules) and return it.
      #    b. Otherwise, fall through to step 2.
      #
      # 2. Determine if input skeleton has both a date and a time part.
      #    a. If yes, split the input skeleton into separate date and time parts, recurse on both, and
      #       combine the results together using the appropriate datetime format.
      #    b. If no, continue to step 3.
      #
      # 3. Find the best skeleton, but allow missing fields.
      #    a. If a skeleton is found, adjust field lengths and append missing fields using the append
      #       items formats from the CLDR data.
      #    b. If no skeleton can be found, return nil. This should realistically only happen if given
      #       an invalid skeleton.
      #
      # In pseudocode:
      #
      # skeleton = find_best_skeleton(skeleton)
      #
      # if skeleton
      #   return adjust(additional_formats[skeleton])
      #
      # if skeleton has date + time:
      #   date_pattern = find_additional_pattern_for(date_fields)
      #   time_pattern = find_additional_pattern_for(time_fields)
      #   return combine_patterns(date_pattern, time_pattern)
      #
      # skeleton, missing = find_best_skeleton(skeleton, allow_missing_fields: true)
      # return unless skeleton
      #
      # add_missing_fields(adjust(additional_formats[skeleton]))
      #
      def find_additional_pattern_for(skeleton)
        if (pattern = pattern_cache[skeleton])
          return pattern
        end

        tokens = tokenize(skeleton)

        if tokens.size == 1
          return pattern_cache[skeleton] = DateTimePattern.new(locale, calendar_type, tokens)
        end

        best_skeleton, missing_fields, adjustments, suppressions = find_best_skeleton(skeleton.to_s)

        if best_skeleton
          best_pattern_str = additional_formats[best_skeleton.to_sym]
          tokens = tokenize(best_pattern_str)
          tokens = suppress(tokens, suppressions)
          tokens = adjust(tokens, skeleton, adjustments)
          tokens = maybe_add_missing_fractional_seconds_to(tokens, missing_fields)
          return pattern_cache[skeleton] = DateTimePattern.new(locale, calendar_type, tokens)
        end

        date_tokens, time_tokens =
          tokenize(skeleton)
            .select { |token| token.type == :date_pattern || token.type == :time_pattern }
            .partition { |token| token.type == :date_pattern }

        date_skeleton = date_tokens.map(&:value).join
        time_skeleton = time_tokens.map(&:value).join

        if !date_skeleton.empty? && !time_skeleton.empty?
          date_pattern = find_additional_pattern_for(date_skeleton)
          time_pattern = find_additional_pattern_for(time_skeleton)
          return combine_patterns(skeleton, date_pattern, time_pattern)
        end

        best_skeleton, missing_fields, adjustments, suppressions = find_best_skeleton(skeleton.to_s, allow_missing_fields: true)
        return unless best_skeleton

        best_pattern_str = additional_formats[best_skeleton.to_sym]
        tokens = tokenize(best_pattern_str)
        tokens = suppress(tokens, suppressions)
        tokens = adjust(tokens, best_skeleton, adjustments)
        tokens = add_missing_fields_to(tokens, missing_fields)
        pattern_cache[skeleton] = DateTimePattern.new(locale, calendar_type, tokens)
      end

      def add_missing_fields_to(tokens, missing_fields)
        missing_fields.each do |field, length|
          # Handle fractional seconds in a special way later
          next if field == "S"

          # period fields should never be appended
          next if field == "a" || field == "b" || field == "B"

          category = FIELD_TO_CATEGORY_MAP[field]
          # @TODO: handle these special cases earlier in the matching process.
          # From TR35: A requested skeleton that includes both seconds and fractional seconds (e.g. "mmssSSS")
          # is allowed to match a dateFormatItem skeleton that includes seconds but not fractional seconds
          # (e.g. “ms”). In this case the requested sequence of ‘S’ characters (or its length) should be retained
          # separately and used when adjusting the pattern.
          next if category == :period || category == :second_fraction

          append_item = append_items[category]
          append_item_tokens = tokenize(append_item)

          # From TR35: "In the pattern, {0} represents the format string, {1} the data content of the field,
          # and {2} the display name of the field."
          tokens = append_item_tokens.flat_map do |token|
            case token.type
              # the format string, i.e. the pattern so far
              when :pos_placeholder0
                tokens
              # the data content of the field, i.e. the part we're adding
              when :pos_placeholder1
                tokenize(field * length)
              # the display name of the field, something like "day" or "week"
              when :pos_placeholder2
                # append items and calendar fields use slightly different names, because of course they do,
                # so we have to translate between the two in order to determine the right text to add
                calendar_field = APPEND_ITEM_CATEGORY_TO_CALENDAR_FIELD_MAP.fetch(category, category)
                TwitterCldr::Tokenizers::Token.new(value: calendar.fields[calendar_field], type: :plaintext)
              else
                token
            end
          end
        end

        maybe_add_missing_fractional_seconds_to(tokens, missing_fields)
      end

      def suppress(tokens, suppressions)
        str = tokens.map(&:value).join

        suppressions.each do |field_char|
          str = str.gsub(field_char, "")
        end

        tokenize(str.gsub(/\s+/, " "))
      end

      def maybe_add_missing_fractional_seconds_to(tokens, missing_fields)
        return tokens unless missing_fields.include?("S")

        tokens.flat_map do |token|
          if token.type == :time_pattern && token.value[0] == "s"
            decimal_separator = number_data_reader.symbols[:decimal]
            decimal_token = TwitterCldr::Tokenizers::Token.new(value: decimal_separator, type: :plaintext)
            frac_sec_token = TwitterCldr::Tokenizers::Token.new(value: "S" * missing_fields["S"], type: :time_pattern)
            [token, decimal_token, frac_sec_token]
          else
            token
          end
        end
      end

      def combine_patterns(skeleton, date_pattern, time_pattern)
        datetime_length =
          if skeleton.include?("MMMM") || skeleton.include?("LLLL")
            if skeleton.include?("E") || skeleton.include?("c")
              :full
            else
              :long
            end
          elsif skeleton.include?("MMM") || skeleton.include?("LLL")
            :medium
          else
            :short
          end

        datetime_pattern = pattern_for(:datetime, :standard, datetime_length)
        datetime_tokens = datetime_pattern.tokens.flat_map do |token|
          case token.type
            when :date_placeholder
              date_pattern.tokens
            when :time_placeholder
              time_pattern.tokens
            else
              token
          end
        end

        pattern_cache[skeleton] = DateTimePattern.new(locale, calendar_type, datetime_tokens)
      end

      def adjust(tokens, skeleton, required_adjustments)
        field_width_map = field_widths_for(skeleton).merge(required_adjustments)

        tokens.map do |token|
          case token.type
            when :date_pattern, :time_pattern
              type_sym = TwitterCldr::Formatters::DateTimeFormatter::PATTERN_MAP[token.value[0]]

              # From TR35: "Pattern field lengths for hour, minute, and second should by default not be adjusted
              # to match the requested field length"
              next token if NON_ADJUST_TYPES.include?(type_sym)

              if field_width_map.include?(token.value[0])
                TwitterCldr::Tokenizers::Token.new(value: token.value[0] * field_width_map[token.value[0]], type: token.type)
              else
                token
              end

            else
              token
          end
        end
      end

      def pattern_cache
        @pattern_cache ||= {}
      end

      def find_best_skeleton(skeleton, allow_missing_fields: false)
        input_field_width_map = field_widths_for(skeleton)
        adjustments = {}
        suppressions = []

        if input_field_width_map.include?("j")
          hour_symbol = hour_data.dig(region.upcase.to_sym, :preferred) || "h"
          hour_width = input_field_width_map["j"].even? ? 2 : 1
          period_width =
            case input_field_width_map["j"]
              when 1, 2
                1
              when 3, 4
                4
              else
                5
            end

          skeleton = skeleton.gsub(/j+/, hour_symbol * hour_width)

          input_field_width_map.delete("j")
          input_field_width_map[hour_symbol] = hour_width
          input_field_width_map["a"] = period_width
          adjustments["a"] = period_width
        elsif input_field_width_map.include?("J")
          hour_symbol = hour_data.dig(region.upcase.to_sym, :preferred) || "H"
          hour_width = input_field_width_map["J"]
          skeleton = skeleton.gsub(/J+/, hour_symbol * hour_width)

          input_field_width_map.delete("J")
          input_field_width_map[hour_symbol] = hour_width
          suppressions.concat(["a", "b", "B"])
        end

        best_skeleton = nil
        best_widths = nil
        best_distance = nil
        best_missing = nil

        opt_field_width_maps = Hash.new do |h, option|
          h[option] = field_widths_for(option)
        end

        additional_format_skeletons.each do |option|
          opt_field_width_map = opt_field_width_maps[option]
          distance = 0
          missing = {}

          TwitterCldr::Formatters::DateTimeFormatter::PATTERN_MAP.each_key do |field|
            input_width = input_field_width_map.fetch(field, 0)
            opt_width = opt_field_width_map.fetch(field, 0)

            # Allow a match even if "S" doesn't exist in the option's skeleton. "S" means fractional seconds and is
            # attached automatically to seconds with the locale's decimal separator.
            next if field == "S"

            # exact field-level match, no need to increase distance value
            next if input_width == opt_width

            # field did not exist in one of the two skeletons
            if opt_width == 0 || input_width == 0
              if opt_width == 0
                missing[field] = input_width
              end

              # always require the skeleton to match "a" if requested
              if !allow_missing_fields || (field == "a" && input_width > 0)
                option = nil
                break
              end

              # magic weight constant for "entirely different fields"
              distance += 0x1000
            elsif field == 'M' && ((input_width > 2 && opt_width <= 2) || (input_width <= 2 && opt_width > 2))
              # magic weight constant for "text turns into a number"
              distance += 0x100
            else
              distance += (input_width - opt_width).abs
            end
          end

          # we lost the option along the way (probably due to allow_missing_fields: false)
          next unless option

          if !best_skeleton || distance < best_distance
            best_skeleton = option
            best_widths = opt_field_width_map
            best_distance = distance
            best_missing = missing
          end

          # found a perfect match!
          break if distance == 0
        end

        return unless best_skeleton

        # treat "S" like a regular missing field and include it even if allow_missing_fields is false since
        # it's special and automatically attached to seconds
        if input_field_width_map.include?("S") && input_field_width_map.include?("s") && !best_widths.include?("S")
          best_missing["S"] = input_field_width_map["S"]
        end

        [best_skeleton, best_missing, adjustments, suppressions]
      end

      def field_widths_for(str)
        tokenize(str).each_with_object({}) do |token, memo|
          next if token.type != :date_pattern && token.type != :time_pattern
          memo[token.value[0]] = token.value.size
        end
      end

      def tokenize(str)
        tokenize_cache[str] ||= TwitterCldr::Tokenizers::DateTimeTokenizer.tokenize(str).freeze
      end

      def tokenize_cache
        @tokenize_cache ||= {}
      end

      def calendar
        @calendar ||= TwitterCldr::Shared::Calendar.new(locale, calendar_type)
      end

      def hour_data
        @@hour_data ||= TwitterCldr.get_resource(:shared, :time_data)[:hours]
      end

      def number_data_reader
        @number_data_reader ||= TwitterCldr::DataReaders::NumberDataReader.new(locale)
      end
    end

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

# pattern = TwitterCldr::Patterns::DateTimePatterns.get(:en).datetime_pattern_for(:full)
# puts pattern.format(DateTime.now)

# pattern = TwitterCldr::Patterns::DateTimePatterns.get(:en).additional_pattern_for(:yyMdEEE)
# puts pattern.format(DateTime.now)

# Checking additional formats attached to length-based patterns
# patterns = TwitterCldr::Patterns::DateTimePatterns.get(:en)
# pattern = patterns.send(:find_additional_pattern_for, "bhmm")
# puts pattern.tokens.map(&:to_s).join
# time = Time.now # Time.parse("2000-01-01T00:00Z[Etc/GMT]")
# puts pattern.format(time, timezone: "UTC")

# exit 0


# require "benchmark/ips"

# time = Time.parse("2000-01-01T00:00Z[Etc/GMT]")

# Benchmark.ips do |x|
#   x.report do
#     pattern = TwitterCldr::Patterns::DateTimePatterns.get(:en).additional_pattern_for(:yyMdEEE)
#     pattern.format(time, timezone: "UTC")
#   end
# end

# exit 0


require "json"

test_cases = JSON.parse(File.read("vendor/cldr_v48.2/common/testData/datetime/datetime.json"))
failures = []

test_cases.each do |test_case|
  if test_case["calendar"] != "gregorian"
    next
  end

  time, timezone = test_case["input"].split(/\[([\w\/]+)\]\z/)
  time = DateTime.parse(time)
  patterns = TwitterCldr::Patterns::DateTimePatterns.get(test_case["locale"])

  if (skeleton = test_case["classicalSkeleton"])
    # binding.irb if skeleton == "yyMdEEE"
    pattern = patterns.send(:find_additional_pattern_for, skeleton) rescue nil
  else
    time_length = nil
    date_length = nil

    if test_case.include?("timeLength")
      time_length = test_case["timeLength"].to_sym
    end

    if test_case.include?("dateLength")
      date_length = test_case["dateLength"].to_sym
    end

    pattern = if time_length && date_length
      format_type = test_case["dateTimeFormatType"]&.to_sym || :atTime
      patterns.datetime_pattern_for(date_length, format_type: format_type, date_length: date_length, time_length: time_length)
    elsif time_length
      patterns.time_pattern_for(time_length)
    else
      patterns.date_pattern_for(date_length)
    end
  end

  expected = TwitterCldr::Normalization.normalize(test_case["expected"], using: :nfkc)

  if !pattern
    # binding.irb
    STDOUT.write("E")
    failures << [test_case.inspect, expected, "Error"]
    next
  end

  got = TwitterCldr::Normalization.normalize(pattern.format(time, timezone: timezone), using: :nfkc)

  if got == expected
    STDOUT.write(".")
  else
    # binding.irb
    STDOUT.write("F")
    failures << [test_case.merge({ pattern: pattern.tokens.map(&:to_s).join }).inspect, expected, got]
  end
end

puts
puts

failures.each_with_index do |(source, expected, got), idx|
  puts "Failure #{idx + 1}:"
  puts "========================="
  puts "  Source: #{source}"
  puts
  puts "Expected: #{expected.inspect}"
  puts "     Got: #{got.inspect}"
  puts
end

puts "#{failures.size} of #{test_cases.count { |tc| tc["calendar"] == "gregorian" }} failed"

# lengths = [
#   ["G", [1, 2, 3, 4]],
#   ["y", [1, 2, 3, 4]],
#   ["Y", [1, 2, 3, 4]],
#   ["Q", [1, 2, 3, 4]],
#   ["q", [1, 2, 3, 4]],
#   ["M", [1, 2, 3, 4, 5]],
#   ["L", [1, 2, 3, 4, 5]],
#   ["w", [1, 2]],
#   ["W", [1]],
#   ["d", [1, 2]],
#   ["D", [1, 2, 3]],
#   ["F", [1]],
#   ["E", [1, 2, 3, 4, 5]],
#   ["e", [1, 2, 3, 4, 5, 6]],
#   ["c", [1, 2, 3, 4, 5, 6]],
#   ["a", [1, 2, 3, 4, 5]],
#   ["B", [1, 2, 3, 4, 5]],
#   ["h", [1, 2]],
#   ["H", [1, 2]],
#   ["K", [1, 2]],
#   ["k", [1, 2]],
#   ["m", [1, 2]],
#   ["s", [1, 2]],
#   ["S", [1, 2, 3, 4]],
#   ["z", [1, 2, 3, 4]],
#   ["Z", [1, 2, 3, 4, 5]],
#   ["O", [1, 4]],
#   ["v", [1, 4]],
#   ["V", [1, 2, 3, 4]],
#   ["X", [1, 2, 3, 4, 5]],
#   ["x", [1, 2, 3, 4, 5]],
# ]

# lengths = lengths.group_by do |field_char, length_nums|
#   TwitterCldr::Patterns::DateTimePatterns::FIELD_TO_CATEGORY_MAP[field_char]
# end.values

# total = lengths.inject(1) do |product, categories|
#   product * (categories.size * 2)
# end

# puts total

# $total = 0
# $passed = 0
# $failed = 0

# def test(patterns, categories, categories_idx, skeleton_parts)
#   if categories_idx == categories.size
#     sk = skeleton_parts.join
#     begin
#       patterns.additional_pattern_for(sk)
#       $passed += 1
#     rescue
#       $failed += 1
#       # puts sk
#       # exit 0
#     end
#     # puts sk if $total % 100_000 == 0
#     $total += 1
#     # puts $total.to_s.reverse.chars.each_slice(3).to_a.map(&:join).join("_").reverse if $total % 10_000 == 0
#     puts "#{$failed} of #{$total} failed, #{$passed} succeeded" if $total % 10_000 == 0
#     return
#   end

#   categories_idx.upto(categories.size - 1) do |i|
#     categories[i].each do |(field_char, field_lengths)|
#       test(patterns, categories, i + 1, [*skeleton_parts, field_char * field_lengths[-1]])
#       # test(patterns, categories, i + 1, skeleton_parts)
#     end
#   end
# end

# patterns = TwitterCldr::Patterns::DateTimePatterns.get(:en)
# test(patterns, lengths, 0, [])

# puts "#{$failed} of #{$total} failed, #{$passed} succeeded"
