# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'fileutils'

module TwitterCldr
  module Resources
    class CollationConformanceTestsImporter < Importer

      TEST_FILES = %w[
        CollationTest_CLDR_NON_IGNORABLE.txt
        CollationTest_CLDR_NON_IGNORABLE_SHORT.txt
      ].freeze

      requirement :cldr, Versions.cldr_version
      output_path 'collation/conformance'
      ruby_engine :mri

      private

      def execute
        TEST_FILES.each do |test_file|
          input_file = File.join(requirements[:cldr].common_path, "uca", test_file)
          output_file = File.join(output_path, test_file)
          FileUtils.mkdir_p(File.dirname(output_file))
          FileUtils.cp(input_file, output_file)
        end
      end

      def output_path
        params[:output_path]
      end
    end
  end
end
