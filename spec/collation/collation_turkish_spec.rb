# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Turkish" do
    let(:source_cases) do
      [
        [0x73, 0x0327],
        [0x76, 0x00E4, 0x74],
        [0x6f, 0x6c, 0x64],
        [0x00FC, 0x6f, 0x69, 0x64],
        [0x68, 0x011E, 0x61, 0x6c, 0x74],
        [0x73, 0x74, 0x72, 0x65, 0x73, 0x015E],
        [0x76, 0x6f, 0x0131, 0x64],
        [0x69, 0x64, 0x65, 0x61],
        [0x00FC, 0x6f, 0x69, 0x64],
        [0x76, 0x6f, 0x0131, 0x64],
        [0x69, 0x64, 0x65, 0x61],
      ]
    end

    let(:target_cases) do
      [
        [0x75, 0x0308],
        [0x76, 0x62, 0x74],
        [0x00D6, 0x61, 0x79],
        [0x76, 0x6f, 0x69, 0x64],
        [0x68, 0x61, 0x6c, 0x74],
        [0x015E, 0x74, 0x72, 0x65, 0x015E, 0x73],
        [0x76, 0x6f, 0x69, 0x64],
        [0x49, 0x64, 0x65, 0x61],
        [0x76, 0x6f, 0x69, 0x64],
        [0x76, 0x6f, 0x69, 0x64],
        [0x49, 0x64, 0x65, 0x61],
      ]
    end

    let(:results) do
      [
        -1,
        -1,
        -1,
        -1,
        1,
        -1,
        -1,
        1,
        # test priamry > 8
        -1,
        -1,
        1,
      ]
    end

    let(:collator) do
      described_class.for(:tr)
    end

    def compare(collator, source, target, result, **options)
      expect(collator.compare(source, target, **options)).to(
        eq(result), "Expected compare(#{source.inspect}, #{target.inspect}) == #{result}"
      )

      source_key = collator.sort_key_for(source, **options)
      target_key = collator.sort_key_for(target, **options)

      expect(source_key <=> target_key).to(
        eq(result), "Expected sort_key(#{source.inspect}) <=> sort_key(#{target.inspect}) == #{result}"
      )
    end

    it "asserts valid tertiary ordering" do
      0.upto(7) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 3
        )
      end
    end

    it "asserts valid primary ordering" do
      8.upto(10) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 1
        )
      end
    end
  end
end
