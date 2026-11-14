# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Spanish" do
    let(:source_cases) do
      [
        [0x61, 0x6c, 0x69, 0x61, 0x73],
        [0x45, 0x6c, 0x6c, 0x69, 0x6f, 0x74],
        [0x48, 0x65, 0x6c, 0x6c, 0x6f],
        [0x61, 0x63, 0x48, 0x63],
        [0x61, 0x63, 0x63],
        [0x61, 0x6c, 0x69, 0x61, 0x73],
        [0x61, 0x63, 0x48, 0x63],
        [0x61, 0x63, 0x63],
        [0x48, 0x65, 0x6c, 0x6c, 0x6f],
      ]
    end

    let(:target_cases) do
      [
        [0x61, 0x6c, 0x6c, 0x69, 0x61, 0x73],
        [0x45, 0x6d, 0x69, 0x6f, 0x74],
        [0x68, 0x65, 0x6c, 0x6c, 0x4f],
        [0x61, 0x43, 0x48, 0x63],
        [0x61, 0x43, 0x48, 0x63],
        [0x61, 0x6c, 0x6c, 0x69, 0x61, 0x73],
        [0x61, 0x43, 0x48, 0x63],
        [0x61, 0x43, 0x48, 0x63],
        [0x68, 0x65, 0x6c, 0x6c, 0x4f],
      ]
    end

    let(:results) do
      [
        -1,
        -1,
        1,
        -1,
        -1,
        # test primary > 5
        -1,
        0,
        -1,
        0
      ]
    end

    let(:collator) do
      described_class.for(:es)
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
      0.upto(4) do |i|
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
      5.upto(8) do |i|
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
