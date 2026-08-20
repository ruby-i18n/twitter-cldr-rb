# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'nokogiri'
require 'fileutils'
require 'parallel'
require 'etc'
require 'set'
require 'yaml'

module TwitterCldr
  module Resources

    class NumberFormatsImporter < Importer

      requirement :cldr, Versions.cldr_version
      output_path 'locales'
      locales TwitterCldr.supported_locales
      ruby_engine :mri

      private

      def execute
        locales = Set.new

        finish = -> (locale, *) do
          locales.add(locale)
          STDOUT.write "\rImported #{locale}, #{locales.size} of #{params[:locales].size} total"
        end

        Parallel.each(params[:locales], in_processes: Etc.nprocessors, finish: finish) do |locale|
          import_locale(locale)
          locales << locale
        end
      end

      def import_locale(locale)
        data = requirements[:cldr].build_data(locale) do |ancestor_locale|
          NumberFormats.new(ancestor_locale, requirements[:cldr]).to_h
        end

        output_file = File.join(output_path, locale.to_s, 'numbers.yml')

        File.open(output_file, 'w:utf-8') do |output|
          output.write(
            ::YAML.dump(locale => TwitterCldr::Utils.squash(data))
          )
        end
      end

      def output_path
        params.fetch(:output_path)
      end

    end


    class NumberFormats

      TYPES = %w(decimal scientific percent currency).freeze

      attr_reader :locale, :cldr_req

      def initialize(locale, cldr_req)
        @locale = locale
        @cldr_req = cldr_req
      end

      def to_h
        {
          numbers: {
            symbols: symbols,
            default_number_systems: default_number_systems,
            formats: TYPES.each_with_object({}) do |type, ret|
              ret[type.to_sym] = formats_for_type(type)
            end
          }
        }
      end

      def symbols
        docset.xpath('//ldml/numbers/symbols').each_with_object({}) do |symbols_node, symbols_result|
          number_system = symbols_node.attribute('numberSystem').value.to_sym

          symbols_result[number_system] = symbols_node.element.element_children.each_with_object({}) do |symbol, symbol_result|
            unless cldr_req.draft?(symbol)
              symbol_name = symbol.name.gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2.downcase}" }
              symbol_result[symbol_name.to_sym] = symbol.content
            end
          end
        end
      end

      def default_number_systems
        { alternatives: {} }.tap do |result|
          docset.xpath('//ldml/numbers/defaultNumberingSystem').each do |default_ns_node|
            if alt_attr = default_ns_node.attribute('alt')
              result[:alternatives][alt_attr.value] = default_ns_node.content
            else
              result[:default] = default_ns_node.content
            end
          end
        end
      end

      def formats_for_type(type)
        docset.xpath("//ldml/numbers/#{type}Formats").each_with_object({}) do |formats_node, ret|
          number_system = formats_node.attribute('numberSystem').value.to_sym
          formats = formats_from_node(formats_node, type, number_system)
          formats[:default] = formats[:default][:default] if formats[:default]

          unit = unit_for(formats_node)

          unless unit.empty?
            formats[:unit] = unit
          end

          ret[number_system] = TwitterCldr::Utils.deep_symbolize_keys(formats)
        end
      end

      def formats_from_node(formats_node, type, number_system)
        formats_node.xpath("#{type}FormatLength").each_with_object({}) do |format_length_node, format_result|
          format_nodes = format_length_node.xpath("#{type}Format")
          format_key = format_length_node.attribute('type')
          format_key = format_key ? format_key.value : :default

          format_nodes.each do |format_node|
            format_result[format_key] ||= patterns_from(format_node)
          end
        end
      end

      def patterns_from(format_node)
        format_node.xpath('pattern').each_with_object({}) do |pattern_node, pattern_result|
          # CLDR v42 added a few new alt patterns, alphaNextToNumber and noCurrency.
          # See: https://cldr.unicode.org/index/downloads/cldr-42#h.ocxunccgtf28
          next if pattern_node.attribute('alt')

          pattern_key_node = pattern_node.attribute('type')
          pattern_count_node = pattern_node.attribute('count')

          unless cldr_req.draft?(pattern_node)
            pattern_key = pattern_key_node ? pattern_key_node.value : :default

            if pattern_count_node
              pattern_count = pattern_count_node.value

              if pattern_result[pattern_key].nil?
                pattern_result[pattern_key] ||= {}
              elsif !pattern_result[pattern_key].is_a?(Hash)
                raise "can't parse patterns with and without 'count' attribute in the same section"
              end

              pattern_result[pattern_key][pattern_count] = pattern_node.content
            else
              pattern_result[pattern_key] = pattern_node.content
            end
          end
        end
      end

      def unit_for(format_length_node)
        format_length_node.xpath('unitPattern').each_with_object({}) do |unit_node, result|
          count = unit_node.attribute('count').value rescue 'one'
          result[count] = unit_node.content
        end
      end

      def docset
        @docset ||= cldr_req.docset(cldr_main_path, locale)
      end

      def cldr_main_path
        @cldr_main_path ||= File.join(cldr_req.common_path, 'main')
      end

    end

  end
end
