# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'yaml'

module TwitterCldr
  module Resources

    class CollationTestsImporter < Importer

      requirement :icu, Versions.icu_version
      locales TwitterCldr.supported_locales
      ruby_engine :jruby
      output_path File.join('collation', 'tests')

      def execute
        params[:locales].each do |target|
          collator = collator_class.getInstance(ulocale_class.new(target.to_s))

          translations = params[:locales].filter_map do |source|
            TwitterCldr::Shared::Languages.from_code_for_locale(source.to_s, target.to_s)
          end

          next if translations.empty?

          translations.sort! do |first, second|
            collator.compare(first, second)
          end

          output_file = File.join(params[:output_path], "#{target}.yml")
          FileUtils.mkdir_p(params[:output_path])
          File.write(output_file, YAML.dump(translations))
        end
      end

      private

      def collator_class
        @collator_class ||= requirements[:icu].get_class("com.ibm.icu.text.Collator")
      end

      def ulocale_class
        @ulocale_class ||= requirements[:icu].get_class("com.ibm.icu.util.ULocale")
      end

    end
  end
end
