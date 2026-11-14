# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Korean Lotus" do
    let(:source_cases) do
      [[0xac00]]
    end

    let(:target_cases) do
      [[0xac01]]
    end

    let(:results) do
      [-1]
    end

    let(:collator) do
      described_class.for(:ko)
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
      compare(
        collator,
        source_cases[0].pack("U*"),
        target_cases[0].pack("U*"),
        results[0],
        maximum_level: 3
      )
    end
  end
end
