# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'yaml'

module TwitterCldr
  module Resources

    class LikelySubtagsTestsImporter < Importer

      requirement :cldr, Versions.cldr_version
      ruby_engine :mri

      private

      def execute
        input_path = File.join(requirements[:cldr].common_path, "testData", "localeIdentifiers", "likelySubtags.txt")
        output_file = File.join(TwitterCldr::SPEC_DIR, "shared", "likely_subtags_tests.yml")

        lines = File
          .read(input_path)
          .split("\n")
          .reject { |line| line.strip == "#" || line.start_with?("# ") }
          .reject(&:empty?)

        tests = lines.map do |line|
          source, add_likely, remove_favor_script, remove_favor_region = line.split(";").map(&:strip)

          {
            source: source,
            add_likely: add_likely,
            remove_favor_script: remove_favor_script,
            remove_favor_region: remove_favor_region.empty? ? nil : remove_favor_region,
          }
        end

        File.write(output_file, ::YAML.dump(tests))
      end

      def output_path
        params.fetch(:output_path)
      end

    end
  end
end
