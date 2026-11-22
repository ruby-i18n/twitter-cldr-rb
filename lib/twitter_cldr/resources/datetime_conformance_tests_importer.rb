# frozen_string_literal: true

require 'fileutils'

module TwitterCldr
  module Resources

    class DatetimeConformanceTestsImporter < Importer

      requirement :cldr, Versions.cldr_version
      output_path File.join('shared', 'calendars')
      locales TwitterCldr.supported_locales
      ruby_engine :mri

      private

      def execute
        input_file = File.join(requirements[:cldr].common_path, 'testData', 'datetime', 'datetime.json')
        output_file = File.join(params[:output_path], "datetime.json")
        FileUtils.cp(input_file, output_file)
      end

    end

  end
end
