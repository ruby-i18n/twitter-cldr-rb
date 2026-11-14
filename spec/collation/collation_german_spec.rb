# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "German" do
    let(:source_cases) do
      [
        [0x47, 0x72, 0x00F6, 0x00DF, 0x65],
        [0x61, 0x62, 0x63],
        [0x54, 0x00F6, 0x6e, 0x65],
        [0x54, 0x00F6, 0x6e, 0x65],
        [0x54, 0x00F6, 0x6e, 0x65],
        [0x61, 0x0308, 0x62, 0x63],
        [0x00E4, 0x62, 0x63],
        [0x00E4, 0x62, 0x63],
        [0x53, 0x74, 0x72, 0x61, 0x00DF, 0x65],
        [0x65, 0x66, 0x67],
        [0x00E4, 0x62, 0x63],
        [0x53, 0x74, 0x72, 0x61, 0x00DF, 0x65],
      ]
    end

    let(:target_cases) do
      [
        [0x47, 0x72, 0x6f, 0x73, 0x73, 0x69, 0x73, 0x74],
        [0x61, 0x0308, 0x62, 0x63],
        [0x54, 0x6f, 0x6e],
        [0x54, 0x6f, 0x64],
        [0x54, 0x6f, 0x66, 0x75],
        [0x41, 0x0308, 0x62, 0x63],
        [0x61, 0x0308, 0x62, 0x63],
        [0x61, 0x65, 0x62, 0x63],
        [0x53, 0x74, 0x72, 0x61, 0x73, 0x73, 0x65],
        [0x65, 0x66, 0x67],
        [0x61, 0x65, 0x62, 0x63],
        [0x53, 0x74, 0x72, 0x61, 0x73, 0x73, 0x65],
      ]
    end

    let(:results) do
      [
        # primary, tertiary
        [-1, -1],
        [0, -1],
        [1, 1],
        [1, 1],
        [1, 1],
        [0, -1],
        [0, 0],
        [-1, -1],
        [0, 1],
        [0, 0],
        [-1, -1],
        [0, 1],
      ]
    end

    let(:collator) do
      described_class.for(:de)
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
      0.upto(11) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i][1],
          maximum_level: 3
        )
      end
    end

    it "asserts valid primary ordering" do
      0.upto(11) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i][0],
          maximum_level: 1
        )
      end
    end
  end
end
