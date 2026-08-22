# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'nokogiri'
require 'open-uri'
require 'yaml'

module TwitterCldr
  module Resources

    class CurrencySymbolsImporter < Importer

      URL = 'https://www.xe.com/symbols.php'.freeze

      output_path 'shared'
      ruby_engine :mri

      private

      def execute
        if symbol_data.size <= 100
          raise "Could only scrape #{symbol_data.size} currency symbols, something is likely wrong"
        end

        path = File.join(params[:output_path], 'iso_currency_symbols.yml')

        File.open(path, 'w:utf-8') do |output|
          output.write(
            ::YAML.dump(
              TwitterCldr::Utils.deep_symbolize_keys(symbol_data)
            )
          )
        end
      end

      def symbol_data
        @symbol_data ||= begin
          # ughh all of this is gross
          doc = Nokogiri::HTML(URI.open(URL).read)
          rows = doc.css('ul:not([class]) li')

          rows.each_with_object({}) do |row, ret|
            columns = row.css('div')
            next if columns[1].text == 'Country and Currency' # skip header

            code = columns[3].text
            symbol = columns[4].text
            ret[code] = { code_points: symbol.codepoints, symbol: symbol }
          end
        end
      end

    end

  end
end
