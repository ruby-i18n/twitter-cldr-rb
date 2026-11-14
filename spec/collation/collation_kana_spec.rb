# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Kana (Japanese)" do
    let(:source_cases) do
      [
        [0xff9E],
        [0x3042],
        [0x30A2],
        [0x3042, 0x3042],
        [0x30A2, 0x30FC],
        [0x30A2, 0x30FC, 0x30C8],
      ]
    end

    let(:target_cases) do
      [
        [0xFF9F],
        [0x30A2],
        [0x3042, 0x3042],
        [0x30A2, 0x30FC],
        [0x30A2, 0x30FC, 0x30C8],
        [0x3042, 0x3042, 0x3068],
      ]
    end

    let(:results) do
      [
        -1, 0, # Katakanas and Hiraganas are equal on tertiary level (ICU 2.0)
        -1, 1, # Prolonged sound mark sorts BEFORE equivalent vowel (ICU 2.0)
        -1,
        -1,    # Prolonged sound mark sorts BEFORE equivalent vowel (ICU 2.0)*//*
      ]
    end

    let(:base_cases) do
      [
        [0x30AB], [0x30AB, 0x30AD], [0x30AD], [0x30AD, 0x30AD],
      ]
    end

    let(:plain_dakuten_handakuten_cases) do
      [
        [0x30CF, 0x30AB],
        [0x30D0, 0x30AB],
        [0x30CF, 0x30AD],
        [0x30D0, 0x30AD],
      ]
    end

    let(:small_large_cases) do
      [
        [0x30C3, 0x30CF],
        [0x30C4, 0x30CF],
        [0x30C3, 0x30D0],
        [0x30C4, 0x30D0],
      ]
    end

    let(:katakana_hiragana_cases) do
      [
        [0x3042, 0x30C3],
        [0x30A2, 0x30C3],
        [0x3042, 0x30C4],
        [0x30A2, 0x30C4],
      ]
    end

    let(:chooon_kigoo_cases) do
      [
        [0x30AB, 0x30FC, 0x3042], # 0
        [0x30AB, 0x30FC, 0x30A2], # 1
        [0x30AB, 0x30A4, 0x3042], # 2
        [0x30AB, 0x30A4, 0x30A2], # 3
        [0x30AD, 0x30FC, 0x3042], # 6
        # Prolonged sound mark sorts BEFORE equivalent vowel (ICU 2.0)
        [0x30AD, 0x30FC, 0x30A2], # 7
        # Prolonged sound mark sorts BEFORE equivalent vowel (ICU 2.0)
        [0x30AD, 0x30A4, 0x3042], # 4
        [0x30AD, 0x30A4, 0x30A2], # 5
      ]
    end

    let(:collator) do
      described_class.for(:ja)
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
      0.upto(5) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 3
        )
      end
    end

    it "asserts valid base ordering" do
      0.upto(2) do |i|
        compare(
          collator,
          base_cases[i].pack("U*"),
          base_cases[i + 1].pack("U*"),
          -1,
          maximum_level: 1
        )
      end
    end

    it "asserts valid plain dakuten handakuten ordering" do
      0.upto(2) do |i|
        compare(
          collator,
          plain_dakuten_handakuten_cases[i].pack("U*"),
          plain_dakuten_handakuten_cases[i + 1].pack("U*"),
          -1,
          maximum_level: 2
        )
      end
    end

    it "asserts valid small/large ordering" do
      0.upto(2) do |i|
        compare(
          collator,
          small_large_cases[i].pack("U*"),
          small_large_cases[i + 1].pack("U*"),
          -1,
          maximum_level: 3
        )
      end
    end

    # needs quaternary comparison functionality
    it "asserts valid katakana/hiragana ordering" do
      0.upto(2) do |i|
        compare(
          collator,
          katakana_hiragana_cases[i].pack("U*"),
          katakana_hiragana_cases[i + 1].pack("U*"),
          -1,
          maximum_level: 4
        )
      end
    end

    # needs quaternary comparison functionality
    it "asserts valid chooon kigoo ordering" do
      0.upto(6) do |i|
        compare(
          collator,
          chooon_kigoo_cases[i].pack("U*"),
          chooon_kigoo_cases[i + 1].pack("U*"),
          -1,
          maximum_level: 4
        )
      end
    end

    # needs quaternary comparison functionality
    it "asserts valid ordering for common characters" do
      tmp1 = [0x3058, 0x30B8]
      tmp2 = [0x3057, 0x3099, 0x30B7, 0x3099]
      string1 = tmp1.pack("U*")
      string2 = tmp2.pack("U*")

      key1 = collator.sort_key_for(string1, maximum_level: 4)
      key2 = collator.sort_key_for(string2, maximum_level: 4)

      key_result = key1 <=> key2
      compare_result = collator.compare(string1, string2, maximum_level: 4)

      expect(key_result).to(eq(0), "Expected #{string1} == #{string2}")
      expect(compare_result).to(eq(0), "Expected #{string1} == #{string2}")
    end
  end
end
