# frozen_string_literal: true

module TwitterCldr
  module Collation
    class CollationSettings
      CASE_MASK = 0xc000
      ONLY_TERTIARY_MASK = 0x3F3F
      CASE_AND_TERTIARY_MASK = CASE_MASK | ONLY_TERTIARY_MASK

      def initialize(**settings_hash)
        @settings_hash = settings_hash
      end

      def backward_secondary?
        @settings_hash[:backward_secondary]
      end

      alias french_collation? backward_secondary?

      def uppercase_first?
        @settings_hash[:uppercase_first]
      end

      def lowercase_first?
        @settings_hash[:lowercase_first]
      end

      def alternate_handling?
        @settings_hash[:alternate_handling]
      end

      def alternate_handling_shifted?
        @settings_hash[:alternate_handling_shifted]
      end

      def case_level?
        @settings_hash[:case_level]
      end

      def variable_top
        @settings_hash[:variable_top]
      end

      def max_variable
        @settings_hash[:max_variable]
      end

      def reorder_table
        @settings_hash[:reorder_table]
      end

      def min_high_no_reorder
        @settings_hash[:min_high_no_reorder]
      end

      def reorder_ranges
        @settings_hash[:reorder_ranges]
      end

      def strength
        @settings_hash[:strength]
      end

      def has_reordering?
        !reorder_table.nil?
      end

      def tertiary_mask
        @tertiary_mask ||= if case_level? || uppercase_first? || lowercase_first?
          CASE_AND_TERTIARY_MASK
        else
          ONLY_TERTIARY_MASK
        end
      end

      def sorts_tertiary_upper_case_first?
        @settings_hash[:sorts_tertiary_upper_case_first]
      end
    end
  end
end
