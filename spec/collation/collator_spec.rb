# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  describe '#each_collation_element' do
    let(:collator) { described_class.for(:root) }

    it 'returns collation elements for a string' do
      expect(collator.each_collation_element('abc').to_a).to(
        eq([3098476543714788608, 3242591731790644480, 3386706919866500352, 4311744768])
      )
    end
  end

  describe '#sort_key_for' do
    let(:collator) { described_class.for(:root) }

    it 'calculates sort key for a string' do
      expect(collator.sort_key_for('abc')).to eq([43, 45, 47, 1, 7, 1, 7])
    end

    it 'respects maximum_level option' do
      expect(collator.sort_key_for('abc', maximum_level: 1)).to eq([43, 45, 47])
    end
  end

  describe '#compare' do
    let(:collator) { described_class.for(:root) }

    it 'compares strings' do
      expect(collator.compare('foo', 'bar')).to eq(1)
      expect(collator.compare('bar', 'foo')).to eq(-1)
    end
  end

  describe 'sorting' do
    let(:collator)  { described_class.for(:root) }
    let(:array)     { %w[bca aaa abc] }
    let(:sorted)    { %w[aaa abc bca] }

    describe '#sort' do
      it 'sorts strings' do
        expect(collator.sort(array)).to eq(sorted)
      end

      it 'does not change the original array' do
        expect { collator.sort(array) }.not_to change { array }
      end
    end

    describe '#sort!' do
      it 'sorts strings array in-place' do
        collator.sort!(array)
        expect(array).to eq(sorted)
      end
    end
  end
end
