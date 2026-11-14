# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

module CollationTestHelpers
  class << self
    # Yields chunk_size chunks that include the previous chunk's last element, which
    # allows us to divide the conformance tests into chunks while testing every pair.
    # See: the use of each_cons(2) in the test below.
    def each_line_chunk(lines, chunk_size)
      return to_enum(__method__, lines, chunk_size) unless block_given?

      last_chunk = nil

      lines.each_slice(chunk_size) do |chunk|
        if last_chunk
          yield [last_chunk.last, *chunk]
        else
          yield chunk
        end

        last_chunk = chunk
      end
    end
  end
end

describe TwitterCldr::Collation::Collator do
  input_file = File.join(TwitterCldr::RESOURCES_DIR, "collation", "conformance", "CollationTest_CLDR_NON_IGNORABLE.txt")
  lines = File.read(input_file)
    .split(/\r?\n/)
    .reject! { |line| line.strip.start_with?("# ") || line.strip.empty? }

  collator = described_class.for(:root)

  CollationTestHelpers.each_line_chunk(lines, 1000).with_index do |chunk, chunk_idx|
    it "passes conformance test chunk #{chunk_idx}" do
      chunk.each_cons(2) do |first, second|
        # strip off comments
        first = first.split(";").first
        second = second.split(";").first

        # convert to codepoint array
        first_cps = first.split(/\s+/).map { |str| str.to_i(16) }
        second_cps = second.split(/\s+/).map { |str| str.to_i(16) }

        # pack codepoints into UTF-8 string
        first_str = first_cps.pack("U*")
        second_str = second_cps.pack("U*")

        # some tests include invalid surrogate pairs for eg. Java, which has UTF-16 strings
        next unless first_str.valid_encoding?
        next unless second_str.valid_encoding?

        # compare via sort keys
        first_key = collator.sort_key_for(first_str, maximum_level: 3)
        second_key = collator.sort_key_for(second_str, maximum_level: 3)
        key_result = first_key <=> second_key

        # compare via comparator
        compare_result = collator.compare(first_str, second_str, maximum_level: 3)

        expect(compare_result == -1 || compare_result == 0).to(eq(true), "Expected #{first} <= #{second}")
        expect(key_result == -1 || key_result == 0).to(eq(true), "Expected sort_key(#{first}) <= sort_key(#{second})")
      end
    end
  end
end
