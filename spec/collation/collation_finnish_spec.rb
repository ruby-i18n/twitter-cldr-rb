# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Finnish" do
    let(:source_cases) do
      [
        [0x77, 0x61, 0x74],
        [0x76, 0x61, 0x74],
        [0x61, 0x00FC, 0x62, 0x65, 0x63, 0x6b],
        [0x4c, 0x00E5, 0x76, 0x69],
        [0x77, 0x61, 0x74],
      ]
    end

    let(:target_cases) do
      [
        [0x76, 0x61, 0x74],
        [0x77, 0x61, 0x79],
        [0x61, 0x78, 0x62, 0x65, 0x63, 0x6b],
        [0x4c, 0x00E4, 0x77, 0x65],
        [0x76, 0x61, 0x74],
      ]
    end

    let(:results) do
      [
        1,
        -1,
        1,
        -1,
        # test primary > 4
        1, # v < w per cldrbug 6615
      ]
    end

    let(:collator) do
      described_class.for(:fi)
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

    it "asserts valid primary ordering" do
      compare(
        collator,
        source_cases[4].pack("U*"),
        target_cases[4].pack("U*"),
        results[4],
        maximum_level: 1
      )
    end

    it "asserts valid tertiary ordering" do
      0.upto(3) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 3
        )
      end
    end
  end
end
