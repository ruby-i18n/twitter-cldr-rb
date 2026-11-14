# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "Thai" do
    let(:collator) do
      described_class.for(:th)
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

    def compare_array(collator, tests)
      tests.each_slice(3) do |left, op, right|
        expect = if op == "<"
          -1
        elsif op == ">"
          1
        else
          0
        end

        compare(collator, left, right, expect, maximum_level: 3)
      end
    end

    it "asserts valid ordering for corner cases" do
      compare_array(
        collator, [
          "ก", "<", "กก",
          "กา", "<", "ก้า",
          "กา", "<", "กา์",
          "กาก้า", "<", "ก่าก้า",
          "กา", "=", "กา-",
          "กา-", "<", "กากา",
          "กา", "=", "กาๆ",
          "กาๆ", "<", "กากา",
          "ฤษี", "<", "ฤๅษี",
          "ฦษี", "<", "ฦๅษี",
          "เกอ", "<", "เกิ",
          "กาก่า", "<", "ก้ากา",
          "ก.ก.", "<", "กา",
        ]
      )
    end

    # Read the external dictionary file, which is already in proper sorted order, and confirm that
    # the collator compares each line as preceding the following line.
    it "asserts valid ordering of dictionary list" do
      lines = File.read(File.join(__dir__, "riwords.txt")).split("\n")
      last_word = nil

      lines.each_with_index do |line, idx|
        # Skip comments and blank lines
        next if line.strip.empty? || line.start_with?("#")

        word = line

        if last_word
          last_key = collator.sort_key_for(last_word)
          key = collator.sort_key_for(word)
          key_result = last_key <=> key
          compare_result = collator.compare(last_word, word)

          expect(key_result <= 0 || compare_result <= 0).to(eq(true), "Expected #{last_word.inspect} <= #{word.inspect} on line #{idx + 1}")
        end

        last_word = word
      end
    end

    it "asserts consistent ordering of invalid thai letters" do
      tests = [
        "\u0E44\u0E01\u0E44\u0E01",
        "\u0E44\u0E01\u0E01\u0E44",
        "\u0E01\u0E44\u0E01\u0E44",
        "\u0E01\u0E01\u0E44\u0E44",
        "\u0E44\u0E44\u0E01\u0E01",
        "\u0E01\u0E44\u0E44\u0E01",
      ]

      tests.sort! do |first, second|
        collator.compare(first, second)
      end

      tests.size.times do |i|
        (i + 1).upto(tests.size - 1) do |j|
          expect(collator.compare(tests[i], tests[j]) <= 0).to(eq(true), "Inconsistent ordering between strings #{i} and #{j}")
        end
      end
    end

    it "asserts valid reordering behavior" do
      compare_array(
        collator, [
          "แć", "=", "แć",
          "แ𝟎", "<", "แ𝟏",
          "แ𝅘𝅥", "=", "แ𝅘𝅥",
          "แ乁", "=", "แ乁",
          "แ́", "=", "แ́",
          "แ̖́", "=", "แ̖́",
          "abcแć", "=", "abcแć",
          "abcแ𝀀", "<", "abcแ𝀁",
          "abcแ𝅘𝅥", "=", "abcแ𝅘𝅥",
          "abcแ乁", "=", "abcแ乁",
          "abcแ́", "=", "abcแ́",
          "abcแ̖́", "=", "abcแ̖́",
          "แćabc", "=", "แćabc",
          "แ𝀀abc", "<", "แ𝀁abc",
          "แ𝅘𝅥abc", "=", "แ𝅘𝅥abc",
          "แ乁abc", "=", "แ乁abc",
          "แ́abc", "=", "แ́abc",
          "แ̖́abc", "=", "แ̖́abc",
          "abcแćabc", "=", "abcแćabc",
          "abcแ𝀀abc", "<", "abcแ𝀁abc",
          "abcแ𝅘𝅥abc", "=", "abcแ𝅘𝅥abc",
          "abcแ乁abc", "=", "abcแ乁abc",
          "abcแ́abc", "=", "abcแ́abc",
          "abcแ̖́abc", "=", "abcแ̖́abc",
        ]
      )
    end
  end
end
