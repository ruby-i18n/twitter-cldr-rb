# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Chinese" do
    let(:collator) do
      described_class.for(:zh)
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

    it "asserts valid pin yin ordering" do
      seq = [
        "\u963f", "\u554a", "\u54ce", "\u6371", "\u7231", "\u9f98", "\u4e5c", "\u8baa",
        "\u4e42", "\u53c8"
      ]

      seq.each_cons(2) do |first, second|
        compare(
          collator,
          first,
          second,
          -1,
          maximum_level: 3
        )
      end
    end
  end
end
