# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'Date/time conformance tests' do
  it 'passes all CLDR date/time conformance tests' do
    input_file = File.join(TwitterCldr::RESOURCES_DIR, "shared", "calendars", "datetime.json")
    test_cases = JSON.parse(File.read(input_file))

    test_cases.each_with_index do |test_case, idx|
      next if test_case["calendar"] != "gregorian"

      time, timezone = test_case["input"].split(/\[([\w\/]+)\]\z/)
      time = DateTime.parse(time)
      patterns = TwitterCldr::Patterns::DateTimePatterns.for(test_case["locale"])

      pattern = if (skeleton = test_case["classicalSkeleton"])
        patterns.send(:find_additional_pattern_for, skeleton) rescue nil
      else
        time_length = nil
        date_length = nil

        if test_case.include?("timeLength")
          time_length = test_case["timeLength"].to_sym
        end

        if test_case.include?("dateLength")
          date_length = test_case["dateLength"].to_sym
        end

        if time_length && date_length
          format_type = test_case["dateTimeFormatType"]&.to_sym || :atTime
          patterns.datetime_pattern_for(date_length, format_type: format_type, date_length: date_length, time_length: time_length)
        elsif time_length
          patterns.time_pattern_for(time_length)
        else
          patterns.date_pattern_for(date_length)
        end
      end

      expect(pattern).to_not(be_nil, "Could not find pattern for #{test_case.inspect}")

      expected = TwitterCldr::Normalization.normalize(test_case["expected"], using: :nfkc)
      got = TwitterCldr::Normalization.normalize(pattern.format(time, timezone: timezone), using: :nfkc)

      expect(expected).to(
        eq(got),
        "Expected '#{expected}', got '#{got}': #{test_case.merge({ pattern: pattern.tokens.map(&:to_s).join }).inspect}"
      )
    end
  end
end
