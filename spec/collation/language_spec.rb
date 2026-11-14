# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Collation::Collator do
  input_path = File.join(TwitterCldr::RESOURCES_DIR, "collation", "tests")
  test_files = Dir.glob(File.join(input_path, "*.yml"))

  test_files.each do |test_file|
    locale = File.basename(test_file).chomp(".yml")

    it "orders languages correctly in #{locale}" do
      collator = described_class.for(locale)
      lines = YAML.load_file(test_file)

      lines.each_cons(2) do |first, second|
        first_key = collator.sort_key_for(first, maximum_level: 3)
        second_key = collator.sort_key_for(second, maximum_level: 3)
        key_result = first_key <=> second_key

        compare_result = collator.compare(first, second, maximum_level: 3)

        expect(compare_result == -1 || compare_result == 0).to(eq(true), "Expected #{first} <= #{second}")
        expect(key_result == -1 || key_result == 0).to(eq(true), "Expected sort_key(#{first}) <= sort_key(#{second})")
      end
    end
  end
end
