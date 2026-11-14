# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "English" do
    let(:source_cases) do
      [
        [
          0x0061, # 'a'
          0x0062, # 'b'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x002D, # '-'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0020, # ' '
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x002D, # '-'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0048, # 'H'
          0x0065, # 'e'
          0x006C, # 'l'
          0x006C, # 'l'
          0x006F, # 'o'
        ],
        [
          0x0041, # 'A'
          0x0042, # 'B'
          0x0043, # 'C'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x002D, # '-'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x002D, # '-'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0070, # 'p'
          0x00EA,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x00E9,
        ],
        [
          0x00C4,
          0x0042, # 'B'
          0x0308,
          0x0043, # 'C'
          0x0308,
        ],
        [
          0x0061, # 'a'
          0x0308,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
          0x0072, # 'r'
        ],
        [
          0x0072, # 'r'
          0x006F, # 'o'
          0x006C, # 'l'
          0x0065, # 'e'
          0x0073, # 's'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0041, # 'A'
        ],
        [
          0x0041, # 'A'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
        ],
        [
          0x0074, # 't'
          0x0063, # 'c'
          0x006F, # 'o'
          0x006D, # 'm'
          0x0070, # 'p'
          0x0061, # 'a'
          0x0072, # 'r'
          0x0065, # 'e'
          0x0070, # 'p'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0069, # 'i'
          0x006E, # 'n'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
        ],
        [
          0x0061, # 'a'
          0x0023, # '#'
          0x0062, # 'b'
        ],
        [
          0x0061, # 'a'
          0x0023, # '#'
          0x0062, # 'b'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0041, # 'A'
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00E6,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0063, # 'c'
          0x0048, # 'H'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0308,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0074, # 't'
          0x0068, # 'h'
          0x0069, # 'i'
          0x0302,
          0x0073, # 's'
        ],
        [
          0x0070, # 'p'
          0x00EA,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x00E6,
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x00E6,
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x00E9,
        ]
      ]
    end

    let(:target_cases) do
      [
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x002D, # '-'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
        ],
        [
          0x0068, # 'h'
          0x0065, # 'e'
          0x006C, # 'l'
          0x006C, # 'l'
          0x006F, # 'o'
        ],
        [
          0x0041, # 'A'
          0x0042, # 'B'
          0x0043, # 'C'
        ],
        [
          0x0041, # 'A'
          0x0042, # 'B'
          0x0043, # 'C'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
          0x0073, # 's'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
          0x0073, # 's'
        ],
        [
          0x0062, # 'b'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0063, # 'c'
          0x006B, # 'k'
          0x0062, # 'b'
          0x0069, # 'i'
          0x0072, # 'r'
          0x0064, # 'd'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x00E9,
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
          0x0072, # 'r'
        ],
        [
          0x00C4,
          0x0042, # 'B'
          0x0308,
          0x0043, # 'C'
          0x0308,
        ],
        [
          0x0041, # 'A'
          0x0308,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
        ],
        [
          0x0072, # 'r'
          0x006F, # 'o'
          0x0302,
          0x006C, # 'l'
          0x0065, # 'e'
        ],
        [
          0x0041, # 'A'
          0x00E1,
          0x0063, # 'c'
          0x0064, # 'd'
        ],
        [
          0x0041, # 'A'
          0x00E1,
          0x0063, # 'c'
          0x0064, # 'd'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0054, # 'T'
          0x0043, # 'C'
          0x006F, # 'o'
          0x006D, # 'm'
          0x0070, # 'p'
          0x0061, # 'a'
          0x0072, # 'r'
          0x0065, # 'e'
          0x0050, # 'P'
          0x006C, # 'l'
          0x0061, # 'a'
          0x0069, # 'i'
          0x006E, # 'n'
        ],
        [
          0x0061, # 'a'
          0x0042, # 'B'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0023, # '#'
          0x0042, # 'B'
        ],
        [
          0x0061, # 'a'
          0x0026, # '&'
          0x0062, # 'b'
        ],
        [
          0x0061, # 'a'
          0x0023, # '#'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00C4,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00C4,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x00C4,
          0x0062, # 'b'
          0x0063, # 'c'
          0x0064, # 'd'
          0x0061, # 'a'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0023, # '#'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x003D, # '='
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0064, # 'd'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0043, # 'C'
          0x0048, # 'H'
          0x0063, # 'c'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0074, # 't'
          0x0068, # 'h'
          0x00EE,
          0x0073, # 's'
        ],
        [
          0x0070, # 'p'
          0x00E9,
          0x0063, # 'c'
          0x0068, # 'h'
          0x00E9,
        ],
        [
          0x0061, # 'a'
          0x0042, # 'B'
          0x0043, # 'C'
        ],
        [
          0x0061, # 'a'
          0x0062, # 'b'
          0x0064, # 'd'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x00C6,
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0042, # 'B'
          0x0064, # 'd'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x00C6,
          0x0063, # 'c'
        ],
        [
          0x0061, # 'a'
          0x0042, # 'B'
          0x0064, # 'd'
        ],
        [
          0x00E4,
          0x0062, # 'b'
          0x0063, # 'c'
        ],
        [
          0x0070, # 'p'
          0x00EA,
          0x0063, # 'c'
          0x0068, # 'h'
          0x0065, # 'e'
        ]
      ]
    end

    let(:results) do
      [
        # -1:LESS; 0:EQUAL; 1:GREATER
        -1,
        -1, # Collator::GREATER
        -1,
        1,
        1,
        0,
        -1,
        -1,
        -1,
        -1, # Collator::GREATER, 10
        1,
        -1,
        0,
        -1,
        1,
        1,
        1,
        -1,
        -1,
        -1, # 20
        -1,
        -1,
        -1,
        1,
        1,
        1,
        # Test Tertiary  > 26
        -1,
        -1,
        1,
        -1, # 30
        1,
        0,
        1,
        -1,
        -1,
        -1,
        # test identical > 36
        0,
        0,
        # test primary > 38
        0,
        0, # 40
        -1,
        0,
        0,
        # test secondary > 43
        -1,
        -1,
        0,
        -1,
        -1,
        -1 # 49
      ]
    end

    let(:bug_cases) do
      [
        [0x61], [0x41], [0x65], [0x45], [0x00e9], [0x00e8], [0x00ea], [0x00eb], [0x65, 0x61], [0x78],
      ]
    end

    let(:acute_cases) do
      # 0x0300 is grave, 0x0301 is acute
      # the order of elements in this array must be different than the order in CollationFrenchTest
      [
        [0x65, 0x65],
        [0x65, 0x65, 0x0301],
        [0x65, 0x65, 0x0301, 0x0300],
        [0x65, 0x65, 0x0300],
        [0x65, 0x65, 0x0300, 0x0301],
        [0x65, 0x0301, 0x65],
        [0x65, 0x0301, 0x65, 0x0301],
        [0x65, 0x0301, 0x65, 0x0301, 0x0300],
        [0x65, 0x0301, 0x65, 0x0300],
        [0x65, 0x0301, 0x65, 0x0300, 0x0301],
        [0x65, 0x0301, 0x0300, 0x65],
        [0x65, 0x0301, 0x0300, 0x65, 0x0301],
        [0x65, 0x0301, 0x0300, 0x65, 0x0301, 0x0300],
        [0x65, 0x0301, 0x0300, 0x65, 0x0300],
        [0x65, 0x0301, 0x0300, 0x65, 0x0300, 0x0301],
        [0x65, 0x0300, 0x65],
        [0x65, 0x0300, 0x65, 0x0301],
        [0x65, 0x0300, 0x65, 0x0301, 0x0300],
        [0x65, 0x0300, 0x65, 0x0300],
        [0x65, 0x0300, 0x65, 0x0300, 0x0301],
        [0x65, 0x0300, 0x0301, 0x65],
        [0x65, 0x0300, 0x0301, 0x65, 0x0301],
        [0x65, 0x0300, 0x0301, 0x65, 0x0301, 0x0300],
        [0x65, 0x0300, 0x0301, 0x65, 0x0300],
        [0x65, 0x0300, 0x0301, 0x65, 0x0300, 0x0301],
      ]
    end

    let(:more_cases) do
      [
        [
          0x0061, # 'a'
          0x0065, # 'e'
        ],
        [0x00E6],
        [0x00C6],
        [
          0x0061, # 'a'
          0x0066, # 'f'
        ],
        [
          0x006F, # 'o'
          0x0065, # 'e'
        ],
        [0x0153],
        [0x0152],
        [
          0x006F, # 'o'
          0x0066, # 'f'
        ],
      ]
    end

    let(:collator) do
      described_class.for(:en)
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
      38.upto(42) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 1
        )
      end
    end

    it "asserts valid secondary ordering" do
      43.upto(48) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 2
        )
      end

      acute_cases.size.times do |i|
        acute_cases.size.times do |j|
          expected = if i < j
            -1
          elsif i == j
            0
          else
            1
          end

          compare(
            collator,
            acute_cases[i].pack("U*"),
            acute_cases[j].pack("U*"),
            expected,
            maximum_level: 2
          )
        end
      end
    end

    it "asserts valid tertiary ordering" do
      0.upto(37) do |i|
        compare(
          collator,
          source_cases[i].pack("U*"),
          target_cases[i].pack("U*"),
          results[i],
          maximum_level: 3
        )
      end

      0.upto(9) do |i|
        (i + 1).upto(9) do |j|
          compare(
            collator,
            bug_cases[i].pack("U*"),
            bug_cases[j].pack("U*"),
            -1,
            maximum_level: 3
          )
        end
      end

      # test more interesting cases
      more_cases.size.times do |i|
        more_cases.size.times do |j|
          expected = if i < j
            -1
          elsif i == j
            0
          else
            1
          end

          compare(
            collator,
            more_cases[i].pack("U*"),
            more_cases[j].pack("U*"),
            expected,
            maximum_level: 3
          )
        end
      end
    end
  end
end
