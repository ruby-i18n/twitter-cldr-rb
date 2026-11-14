# frozen_string_literal: true

module TwitterCldr
  module Collation
    class CollationComparator
      MERGE_SEPARATOR_PRIMARY = 0x02000000  # U+FFFE
      NO_CE_PRIMARY = 1  # not a left-adjusted weight
      NO_CE_WEIGHT16 = 0x0100  # weight of LEVEL_SEPARATOR_BYTE
      NO_CE = 0x101000100

      LESS = -1
      EQUAL = 0
      GREATER = 1

      attr_reader :locale

      class << self
        def for(locale)
          cache[locale] ||= new(locale)
        end

        private

        def cache
          @cache ||= {}
        end
      end

      def initialize(locale)
        @locale = locale == :root ? locale : TwitterCldr.normalize_locale(locale)
      end

      def compare(left, right, **options)
        maximum_level = options[:maximum_level] || 3

        result = nil

        result ||= compare_primary(left, right)
        result ||= compare_secondary(left, right)             if maximum_level >= 2
        result ||= compare_case_level(left, right, **options) if settings.case_level?

        return result if result
        return EQUAL if maximum_level <= 2

        result ||= compare_tertiary(left, right, **options)   if maximum_level >= 3
        result ||= compare_quaternary(left, right)            if maximum_level == 4

        result || EQUAL
      end

      private

      def compare_primary(left, right)
        # Fetch CEs, compare primaries, store secondary & tertiary weights.
        loop do
          left_primary = find_primary(left)
          right_primary = find_primary(right)

          if left_primary != right_primary
            # Return the primary difference, with script reordering.
            if reorder?
              left_primary = reorder(left_primary)
              right_primary = reorder(right_primary)
            end

            return (left_primary < right_primary) ? LESS : GREATER
          end

          break if left_primary == NO_CE_PRIMARY
        end

        nil
      end

      def find_primary(iter)
        # We fetch CEs until we get a non-ignorable primary or reach the end.
        loop do
          ce = iter.next_ce
          primary = (ce >> 32) & 0xFFFF_FFFF

          if primary < variable_top && primary > MERGE_SEPARATOR_PRIMARY
            # Variable CE, shift it to quaternary level.
            # Ignore all following primary ignorables, and shift further variable CEs.
            loop do
              # Store only the primary of the variable CE.
              iter.set_current(ce & 0xFFFF_FFFF_0000_0000)

              loop do
                ce = iter.next_ce
                primary = (ce >> 32) & 0xFFFF_FFFF

                if primary == 0
                  iter.set_current(0)
                else
                  break
                end
              end

              if primary >= variable_top || primary <= MERGE_SEPARATOR_PRIMARY
                break
              end
            end
          end

          return primary if primary != 0
        end

        nil
      end

      def compare_secondary(left, right)
        # Compare the buffered secondary & tertiary weights.
        # We might skip the secondary level but continue with the case level
        # which is turned on separately.
        if backward_secondary?
          compare_secondary_backwards(left, right)
        else
          compare_secondary_forwards(left, right)
        end
      end

      def compare_secondary_forwards(left, right)
        left_index = 0
        right_index = 0

        loop do
          left_secondary = nil

          loop do
            left_secondary = ((left.at(left_index) & 0xFFFF_FFFF) >> 16) & 0xFFFF
            left_index += 1

            break if left_secondary != 0
          end

          right_secondary = nil

          loop do
            right_secondary = ((right.at(right_index) & 0xFFFF_FFFF) >> 16) & 0xFFFF
            right_index += 1

            break if right_secondary != 0
          end

          if left_secondary != right_secondary
            return (left_secondary < right_secondary) ? LESS : GREATER
          end

          break if left_secondary == NO_CE_WEIGHT16
        end

        nil
      end

      def compare_secondary_backwards(left, right)
        # The backwards secondary level compares secondary weights backwards
        # within segments separated by the merge separator (U+FFFE, weight 02).
        left_start = 0
        right_start = 0

        loop do
          # Find the merge separator or the NO_CE terminator.
          p = nil
          left_limit = left_start

          while (p = (left.at(left_limit) >> 32) & 0xFFFF_FFFF) > MERGE_SEPARATOR_PRIMARY || p == 0
            left_limit += 1
          end

          right_limit = right_start

          while (p = (right.at(right_limit) >> 32) & 0xFFFF_FFFF) > MERGE_SEPARATOR_PRIMARY || p == 0
            right_limit += 1
          end

          # Compare the segments.
          left_index = left_limit
          right_index = right_limit

          loop do
            left_secondary = 0

            while left_secondary == 0 && left_index > left_start
              left_index -= 1
              left_secondary = ((left.at(left_index) & 0xFFFF_FFFF) >> 16) & 0xFFFF
            end

            right_secondary = 0

            while right_secondary == 0 && right_index > right_start
              right_index -= 1
              right_secondary = ((right.at(right_index) & 0xFFFF_FFFF) >> 16) & 0xFFFF
            end

            if left_secondary != right_secondary
              return (left_secondary < right_secondary) ? LESS : GREATER
            end

            break if left_secondary == 0
          end

          # Did we reach the end of either string?
          # Both strings have the same number of merge separators,
          # or else there would have been a primary-level difference.
          # assert (left.at(left_limit) == right.at(right_limit))
          break if p == NO_CE_PRIMARY

          # Skip both merge separators and continue.
          left_start = left_limit + 1
          right_start = right_limit + 1
        end

        nil
      end

      def compare_case_level(left, right, **options)
        maximum_level = options[:maximum_level] || 3

        if maximum_level == 1
          compare_case_level_primary(left, right)
        else
          compare_case_level_secondary(left, right)
        end
      end

      def compare_case_level_primary(left, right)
        left_index = 0
        right_index = 0

        loop do
          left_case, left_lower32, right_case = nil

          # Primary+caseLevel: Ignore case level weights of primary ignorables.
          # Otherwise we would get a-umlaut > a
          # which is not desirable for accent-insensitive sorting.
          # Check for (lower 32 bits) == 0 as well because variable CEs are stored
          # with only primary weights.
          ce = nil

          loop do
            ce = left.at(left_index)
            left_index += 1
            left_case = ce & 0xFFFF_FFFF

            break if ((ce >> 32) & 0xFFFF_FFFF) != 0 && left_case != 0
          end

          left_lower32 = left_case
          left_case &= 0xC000

          loop do
            ce = right.at(right_index)
            right_index += 1
            right_case = ce & 0xFFFF_FFFF

            break if ((ce >> 32) & 0xFFFF_FFFF) != 0 || right_case != 0
          end

          right_case &= 0xC000

          # No need to handle NO_CE and MERGE_SEPARATOR specially:
          # There is one case weight for each previous-level weight,
          # so level length differences were handled there.
          if left_case != right_case
            if !settings.uppercase_first?
              return (left_case < right_case) ? LESS : GREATER
            else
              return (left_case < right_case) ? GREATER : LESS
            end
          end

          break if ((left_lower32 >> 16) & 0xFFFF_FFFF) == NO_CE_WEIGHT16
        end

        nil
      end

      def compare_case_level_secondary(left, right)
        left_index = 0
        right_index = 0

        loop do
          left_case, left_lower32, right_case = nil

          # Secondary+caseLevel: By analogy with the above,
          # ignore case level weights of secondary ignorables.
          #
          # Note: A tertiary CE has uppercase case bits (0.0.ut)
          # to keep tertiary+caseFirst well-formed.
          #
          # Tertiary+caseLevel: Also ignore case level weights of secondary ignorables.
          # Otherwise a tertiary CE's uppercase would be no greater than
          # a primary/secondary CE's uppercase.
          # (See UCA well-formedness condition 2.)
          # We could construct a special case weight higher than uppercase,
          # but it's simpler to always ignore case weights of secondary ignorables,
          # turning 0.0.ut into 0.0.0.t.
          # (See LDML Collation, Case Parameters.)
          loop do
            left_case = left.at(left_index) & 0xFFFF_FFFF
            left_index += 1

            break if (left_case & 0xFFFF_0000) != 0
          end

          left_lower32 = left_case
          left_case &= 0xC000

          loop do
            right_case = right.at(right_index) & 0xFFFF_FFFF
            right_index += 1

            break if (right_case & 0xFFFF_0000) != 0
          end

          right_case &= 0xC000

          # No need to handle NO_CE and MERGE_SEPARATOR specially:
          # There is one case weight for each previous-level weight,
          # so level length differences were handled there.
          if left_case != right_case
            if !settings.uppercase_first?
              return (left_case < right_case) ? LESS : GREATER
            else
              return (left_case < right_case) ? GREATER : LESS
            end
          end

          break if ((left_lower32 >> 16) & 0xFFFF_FFFF) == NO_CE_WEIGHT16
        end

        nil
      end

      def compare_tertiary(left, right, **options)
        maximum_level = options[:maximum_level] || 3

        left_index = 0
        right_index = 0
        any_quaternaries = 0

        loop do
          left_lower32, left_tertiary = nil

          loop do
            left_lower32 = left.at(left_index) & 0xFFFF_FFFF
            left_index += 1
            any_quaternaries |= left_lower32
            left_tertiary = left_lower32 & settings.tertiary_mask

            break if left_tertiary != 0
          end

          right_lower32, right_tertiary = nil

          loop do
            right_lower32 = right.at(right_index) & 0xFFFF_FFFF
            right_index += 1
            any_quaternaries |= right_lower32
            right_tertiary = right_lower32 & settings.tertiary_mask

            break if right_tertiary != 0
          end

          if left_tertiary != right_tertiary
            if settings.sorts_tertiary_upper_case_first?
              # Pass through NO_CE and keep real tertiary weights larger than that.
              # Do not change the artificial uppercase weight of a tertiary CE (0.0.ut),
              # to keep tertiary CEs well-formed.
              # Their case+tertiary weights must be greater than those of
              # primary and secondary CEs.
              if left_tertiary > NO_CE_WEIGHT16
                if (left_lower32 & 0xFFFF_0000) != 0
                  left_tertiary ^= 0xC000
                else
                  left_tertiary += 0x4000
                end
              end

              if right_tertiary > NO_CE_WEIGHT16
                if (right_lower32 & 0xFFFF_0000) != 0
                  right_tertiary ^= 0xC000
                else
                  right_tertiary += 0x4000
                end
              end
            end

            return (left_tertiary < right_tertiary) ? LESS : GREATER
          end

          break if left_tertiary == NO_CE_WEIGHT16
        end

        return EQUAL if maximum_level <= 3

        any_variable = any_variable?(left) || any_variable?(right)

        if !any_variable && (any_quaternaries & 0xC0) == 0
          # If there are no "variable" CEs and no non-zero quaternary weights,
          # then there are no quaternary differences.
          return EQUAL
        end

        nil
      end

      def compare_quaternary(left, right)
        left_index = 0
        right_index = 0

        loop do
          left_quaternary = nil

          loop do
            ce = left.at(left_index)
            left_index += 1
            left_quaternary = ce & 0xFFFF

            if left_quaternary <= NO_CE_WEIGHT16
              # Variable primary or completely ignorable or NO_CE.
              left_quaternary = (ce >> 32) & 0xFFFF_FFFF
            else
              # Regular CE, not tertiary ignorable.
              # Preserve the quaternary weight in bits 7..6.
              left_quaternary |= 0xFFFF_FF3F
            end

            break if left_quaternary != 0
          end

          right_quaternary = nil

          loop do
            ce = right.at(right_index)
            right_index += 1
            right_quaternary = ce & 0xFFFF

            if right_quaternary <= NO_CE_WEIGHT16
              # Variable primary or completely ignorable or NO_CE.
              right_quaternary = (ce >> 32) & 0xFFFF_FFFF
            else
              # Regular CE, not tertiary ignorable.
              # Preserve the quaternary weight in bits 7..6.
              right_quaternary |= 0xFFFF_FF3F
            end

            break if right_quaternary != 0
          end

          if left_quaternary != right_quaternary
            # Return the difference, with script reordering.
            if reorder?
              left_quaternary = reorder(left_quaternary)
              right_quaternary = reorder(right_quaternary)
            end

            return (left_quaternary < right_quaternary) ? LESS : GREATER
          end

          break if left_quaternary == NO_CE_PRIMARY
        end
      end

      def any_variable?(iter)
        index = 0

        loop do
          ce = iter.at(index)
          index += 1
          break unless ce

          primary = (ce >> 32) & 0xFFFF_FFFF

          if primary < variable_top && primary > MERGE_SEPARATOR_PRIMARY
            return true
          end
        end

        false
      end

      def variable_top
        @variable_top ||= if settings.alternate_handling?
          settings.variable_top + 1
        else
          0
        end
      end

      def reorder?
        settings.has_reordering?
      end

      def backward_secondary?
        settings.backward_secondary?
      end

      def reorder(primary_weight)
        b = settings.reorder_table[(primary_weight >> 24) & 0xFFFF_FFFF]

        if b != 0 || primary_weight <= 1
          ((b & 0xFF) << 24) | (primary_weight & 0xFF_FFFF)
        else
          reorder_ex(primary_weight)
        end
      end

      def reorder_ex(primary_weight)
        if settings.min_high_no_reorder <= 0
          raise "Expected settings.min_high_no_reorder > 0"
        end

        return primary_weight if primary_weight >= settings.min_high_no_reorder

        # Round up p so that its lower 16 bits are >= any offset bits.
        # Then compare q directly with (limit, offset) pairs.
        q = primary_weight | 0xFFFF
        i = 0

        i += 1 while q >= (r = settings.reorder_ranges[i])
        primary_weight + ((r << 24) & 0xFFFF)
      end

      def settings
        @settings ||= TwitterCldr::Collation::TailoredCollationData.for_locale(locale).settings
      end
    end
  end
end
