# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  context "French" do
    let(:source_cases) do
      [
        [0x0061, 0x0062, 0x0063],
        [0x0043, 0x004f, 0x0054, 0x0045],
        [0x0063, 0x006f, 0x002d, 0x006f, 0x0070],
        [0x0070, 0x00EA, 0x0063, 0x0068, 0x0065],
        [0x0070, 0x00EA, 0x0063, 0x0068, 0x0065, 0x0072],
        [0x0070, 0x00E9, 0x0063, 0x0068, 0x0065, 0x0072],
        [0x0070, 0x00E9, 0x0063, 0x0068, 0x0065, 0x0072],
        [0x0048, 0x0065, 0x006c, 0x006c, 0x006f],
        [0x01f1],
        [0xfb00],
        [0x01fa],
        [0x0101],
      ]
    end

    let(:target_cases) do
      [
        [0x0041, 0x0042, 0x0043],
        [0x0063, 0x00f4, 0x0074, 0x0065],
        [0x0043, 0x004f, 0x004f, 0x0050],
        [0x0070, 0x00E9, 0x0063, 0x0068, 0x00E9],
        [0x0070, 0x00E9, 0x0063, 0x0068, 0x00E9],
        [0x0070, 0x00EA, 0x0063, 0x0068, 0x0065],
        [0x0070, 0x00EA, 0x0063, 0x0068, 0x0065, 0x0072],
        [0x0068, 0x0065, 0x006c, 0x006c, 0x004f],
        [0x01ee],
        [0x25ca],
        [0x00e0],
        [0x01df],
      ]
    end

    let(:results) do
      [-1, -1, -1, -1, 1, 1, -1, 1, -1, 1, -1, -1]
    end

    let(:acute_cases) do
      [
        [0x0065, 0x0065],
        [0x0065, 0x0301, 0x0065],
        [0x0065, 0x0300, 0x0301, 0x0065],
        [0x0065, 0x0300, 0x0065],
        [0x0065, 0x0301, 0x0300, 0x0065],
        [0x0065, 0x0065, 0x0301],
        [0x0065, 0x0301, 0x0065, 0x0301],
        [0x0065, 0x0300, 0x0301, 0x0065, 0x0301],
        [0x0065, 0x0300, 0x0065, 0x0301],
        [0x0065, 0x0301, 0x0300, 0x0065, 0x0301],
        [0x0065, 0x0065, 0x0300, 0x0301],
        [0x0065, 0x0301, 0x0065, 0x0300, 0x0301],
        [0x0065, 0x0300, 0x0301, 0x0065, 0x0300, 0x0301],
        [0x0065, 0x0300, 0x0065, 0x0300, 0x0301],
        [0x0065, 0x0301, 0x0300, 0x0065, 0x0300, 0x0301],
        [0x0065, 0x0065, 0x0300],
        [0x0065, 0x0301, 0x0065, 0x0300],
        [0x0065, 0x0300, 0x0301, 0x0065, 0x0300],
        [0x0065, 0x0300, 0x0065, 0x0300],
        [0x0065, 0x0301, 0x0300, 0x0065, 0x0300],
        [0x0065, 0x0065, 0x0301, 0x0300],
        [0x0065, 0x0301, 0x0065, 0x0301, 0x0300],
        [0x0065, 0x0300, 0x0301, 0x0065, 0x0301, 0x0300],
        [0x0065, 0x0300, 0x0065, 0x0301, 0x0300],
        [0x0065, 0x0301, 0x0300, 0x0065, 0x0301, 0x0300],
      ]
    end

    let(:bug_cases) do
      [
        [0x0061],
        [0x0041],
        [0x0065],
        [0x0045],
        [0x00e9],
        [0x00e8],
        [0x00ea],
        [0x00eb],
        [0x0065, 0x0061],
        [0x0078],
      ]
    end

    let(:collator) do
      described_class.for(:fr_CA)
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
          results[i],
          maximum_level: 3
        )
      end
    end

    it "asserts valid secondary ordering" do
      # test acute and grave ordering
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

    it "asserts bugs are addressed" do
      0.upto(8) do |i|
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
    end
  end
end
