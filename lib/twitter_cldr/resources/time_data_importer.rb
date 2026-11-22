# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'nokogiri'
require 'fileutils'
require 'yaml'

module TwitterCldr
  module Resources

    class TimeDataImporter < Importer

      requirement :cldr, Versions.cldr_version

      output_path 'shared'
      ruby_engine :mri

      private

      def execute
        output_file = File.join(output_path, 'time_data.yml')
        FileUtils.mkdir_p(File.dirname(output_file))

        File.open(output_file, 'w:utf-8') do |output|
          output.write(
            ::YAML.dump(
              TwitterCldr::Utils.squash(
                TwitterCldr::Utils.deep_symbolize_keys(time_data)
              )
            )
          )
        end
      end

      def time_data
        { hours: hours }
      end

      def hours
        {}.tap do |memo|
          doc.xpath('//supplementalData/timeData/hours').each do |hour_node|
            preferred = hour_node.attribute("preferred").value
            allowed = hour_node.attribute("allowed").value.split(/\s+/)
            regions = hour_node.attribute("regions").value.split(/\s+/)

            regions.each do |region|
              memo[region.to_sym] = {
                preferred: preferred,
                allowed: allowed,
              }
            end
          end
        end
      end

      def input_file
        @input_file ||= File.join(
          requirements[:cldr].common_path, 'supplemental', 'supplementalData.xml'
        )
      end

      def output_path
        params.fetch(:output_path)
      end

      def doc
        @doc ||= Nokogiri.XML(File.read(input_file))
      end

      def cldr_main_path
        @cldr_main_path ||= File.join(cldr_req.common_path, 'main')
      end

    end

  end
end
