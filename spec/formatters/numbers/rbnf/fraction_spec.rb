# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

# Expected values are ICU4J 76.1's output for the same rule sets.
describe TwitterCldr::Formatters::Rbnf::RbnfFormatter do
  def format(locale, number, rule_set)
    described_class.new(locale).format(number, rule_group: 'SpelloutRules', rule_set: rule_set)
  end

  context 'with a fraction rule set (">%%fractions>")' do
    it 'spells the fractional part as a fraction with denominators' do
      expect(format(:ru, 2.25, 'spellout-cardinal-feminine')).to eq('две целых двадцать пять сотых')
      expect(format(:ru, 21.001, 'spellout-cardinal-feminine')).to eq('двадцать одна целая одна тысячная')
      expect(format(:ru, 2.25, 'spellout-cardinal-masculine-genitive')).to eq('двух целых двадцати пяти сотых')
      expect(format(:kk, 2.25, 'spellout-cardinal')).to eq('екі бүтін жүзден жиырма бес')
    end

    it 'agrees the plural form with the integral part' do
      expect(format(:ru, 1.5, 'spellout-cardinal-feminine')).to eq('одна целая пять десятых')
    end

    it 'uses the improper fraction rule below one when there is no proper fraction rule' do
      expect(format(:ru, 0.5, 'spellout-cardinal-feminine')).to eq('пять десятых')
    end

    it 'keeps leading zeros for a doubled arrow ("<%set<<")' do
      expect(format(:pl, 2.25, 'spellout-cardinal-masculine')).to eq('dwa przecinek dwadzieścia pięć')
      expect(format(:pl, 21.001, 'spellout-cardinal-masculine')).to eq('dwadzieścia jeden przecinek zero zero jeden')
    end
  end

  context 'with digits (">>")' do
    it 'spells each digit separated by spaces' do
      expect(format(:en, 2.25, 'spellout-cardinal')).to eq('two point two five')
      expect(format(:en, 0.5, 'spellout-cardinal')).to eq('zero point five')
    end

    it 'spells each digit without spaces for ">>>"' do
      expect(format(:ja, 0.05, 'spellout-numbering')).to eq('〇・〇五')
      expect(format(:ko, 2.25, 'spellout-cardinal-sinokorean')).to eq('이점이오')
    end
  end
end
