# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr do
  describe "#supported_locale?" do
    it "should return true if the locale is supported" do
      expect(TwitterCldr.supported_locale?(:es)).to eq(true)
      expect(TwitterCldr.supported_locale?("es")).to eq(true)
    end

    it "should return false if the locale isn't supported" do
      expect(TwitterCldr.supported_locale?(:bogus)).to eq(false)
      expect(TwitterCldr.supported_locale?("bogus")).to eq(false)
    end

    it "should work with lowercase region codes" do
      expect(TwitterCldr.supported_locale?('en-gb')).to eq(true)
      expect(TwitterCldr.supported_locale?('zh-hant')).to eq(true)
    end

    it "should work with upper case region codes" do
      expect(TwitterCldr.supported_locale?('en-GB')).to eq(true)
      expect(TwitterCldr.supported_locale?('zh-Hant')).to eq(true)
    end
  end

  describe "#supported_locales" do
    it "should return an array of currently supported locale codes" do
      locales = TwitterCldr.supported_locales
      expect(locales).to include(:es)
      expect(locales).to include(:zh)
      expect(locales).to include(:no)
      expect(locales).to include(:ja)
    end

    it 'should not include :shared or :unicode_data' do
      expect(TwitterCldr.supported_locales & [:shared, :unicode_data]).to be_empty
    end
  end

  describe "#normalize_locale" do
    it "should fallback to language if locale is unsupported but language is" do
      expect(TwitterCldr.normalize_locale(:'pt-BR')).to eq(:pt)
      expect(TwitterCldr.normalize_locale(:'zh-Hans-CN')).to eq(:zh)
    end

    it "should leave known locales alone" do
      expect(TwitterCldr.normalize_locale(:fr)).to eq(:fr)
      expect(TwitterCldr.normalize_locale(:'fr-ca')).to eq(:'fr-CA')
      expect(TwitterCldr.normalize_locale(:'fr-CA')).to eq(:'fr-CA')
      expect(TwitterCldr.normalize_locale(:'es-419')).to eq(:'es-419')
    end
  end

  describe "#locale" do
    context "with explicit locale" do
      it "should return the same locale the user sets (if it's supported)" do
        TwitterCldr.locale = :es
        expect(TwitterCldr.locale).to eq(:es)
      end

      it "should convert strings to symbols" do
        TwitterCldr.locale = "es"
        expect(TwitterCldr.locale).to eq(:es)
      end
    end

    context "with implicit locale (fallbacks)" do
      before(:each) do
        TwitterCldr.locale = nil
      end

      context "with I18n locale" do
        it "should return the I18n locale if it's supported" do
          I18n.locale = "ru"
          expect(TwitterCldr.locale).to eq(:ru)
        end

        it "should blow up if the I18n locale is unsupported" do
          I18n.locale = "bogus"
          expect { TwitterCldr.locale }.to raise_error(TwitterCldr::UnsupportedLocaleError)
        end
      end
    end
  end

  describe "#with_locale" do
    it "should only change the locale in the context of the block" do
      expect(TwitterCldr::Shared::Languages.from_code(:es)).to eq("Spanish")
      expect(TwitterCldr.with_locale(:es) { TwitterCldr::Shared::Languages.from_code(:es) }).to match_normalized("español")
      expect(TwitterCldr::Shared::Languages.from_code(:es)).to eq("Spanish")
    end

    it "switches the locale back to the original if the block raises an error" do
      expect(TwitterCldr.locale).to eq(:en)
      locale_inside_block = nil

      expect do
        TwitterCldr.with_locale(:es) do
          locale_inside_block = TwitterCldr.locale
          raise RuntimeError, "Error!"
        end
      end.to raise_error(RuntimeError, "Error!")

      expect(locale_inside_block).to eq(:es)
      expect(TwitterCldr.locale).to eq(:en)
    end
  end

  describe "#with_locale" do
    it "should only change the locale in the context of the block" do
      expect(TwitterCldr::Shared::Languages.from_code(:es)).to eq("Spanish")
      expect(TwitterCldr.with_locale(:es) { TwitterCldr::Shared::Languages.from_code(:es) }).to match_normalized("español")
      expect(TwitterCldr::Shared::Languages.from_code(:es)).to eq("Spanish")
    end

    it "doesn't mess up if the given locale isn't supported" do
      TwitterCldr.locale = :pt
      expect(TwitterCldr.locale).to eq(:pt)
      expect { TwitterCldr.with_locale(:xx) {} }.to(
        raise_error(TwitterCldr::UnsupportedLocaleError, "':xx' is not a supported locale")
      )
      expect(TwitterCldr.locale).to eq(:pt)
    end

    it "switches the locale back to the original if the block raises an error" do
      expect(TwitterCldr.locale).to eq(:en)
      locale_inside_block = nil

      expect do
        TwitterCldr.with_locale(:es) do
          locale_inside_block = TwitterCldr.locale
          raise RuntimeError, "Error!"
        end
      end.to raise_error(RuntimeError, "Error!")

      expect(locale_inside_block).to eq(:es)
      expect(TwitterCldr.locale).to eq(:en)
    end
  end

  describe '#resources' do
    it 'returns @resources' do
      resources = TwitterCldr::Resources::Loader.new
      TwitterCldr.instance_variable_set(:@resources, resources)

      expect(TwitterCldr.resources).to eq(resources)
    end
  end

  let(:resources) { TwitterCldr::Resources::Loader.new }

  describe '#get_resource' do
    it 'delegates to resources' do
      allow(resources).to receive(:get_resource).with(:shared, :currencies).and_return('result')
      allow(TwitterCldr).to receive(:resources).and_return(resources)

      expect(TwitterCldr.get_resource(:shared, :currencies)).to eq('result')
    end
  end

  describe '#get_locale_resource' do
    it 'delegates to resources' do
      allow(resources).to receive(:get_locale_resource).with(:de, :numbers).and_return('result')
      allow(TwitterCldr).to receive(:resources).and_return(resources)

      expect(TwitterCldr.get_locale_resource(:de, :numbers)).to eq('result')
    end
  end
end
