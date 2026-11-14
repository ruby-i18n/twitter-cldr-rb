# frozen_string_literal: true

module TwitterCldr
  module Collation
    class SortKeyWriter
      COMMON_BYTE = 5
      COMMON_WEIGHT16 = 0x0500

      LEVEL_SEPARATOR_BYTE = 1
      MERGE_SEPARATOR_BYTE = 2

      PRIMARY_COMPRESSION_LOW_BYTE = 3
      PRIMARY_COMPRESSION_HIGH_BYTE = 0xFF

      # Secondary level: Compress up to 33 common weights as 05..25 or 25..45.
      SEC_COMMON_LOW = COMMON_BYTE
      SEC_COMMON_MIDDLE = SEC_COMMON_LOW + 0x20
      SEC_COMMON_HIGH = SEC_COMMON_LOW + 0x40
      SEC_COMMON_MAX_COUNT = 0x21

      # Case level, lowerFirst: Compress up to 7 common weights as 1..7 or 7..13.
      CASE_LOWER_FIRST_COMMON_LOW = 1
      CASE_LOWER_FIRST_COMMON_MIDDLE = 7
      CASE_LOWER_FIRST_COMMON_HIGH = 13
      CASE_LOWER_FIRST_COMMON_MAX_COUNT = 7

      # Case level, upperFirst: Compress up to 13 common weights as 3..15.
      CASE_UPPER_FIRST_COMMON_LOW = 3
      CASE_UPPER_FIRST_COMMON_MAX_COUNT = 13

      # Tertiary level only (no case): Compress up to 97 common weights as 05..65 or 65..C5.
      TER_ONLY_COMMON_LOW = COMMON_BYTE
      TER_ONLY_COMMON_MIDDLE = TER_ONLY_COMMON_LOW + 0x60
      TER_ONLY_COMMON_HIGH = TER_ONLY_COMMON_LOW + 0xC0
      TER_ONLY_COMMON_MAX_COUNT = 0x61

      # Tertiary with case, lowerFirst: Compress up to 33 common weights as 05..25 or 25..45.
      TER_LOWER_FIRST_COMMON_LOW = COMMON_BYTE
      TER_LOWER_FIRST_COMMON_MIDDLE = TER_LOWER_FIRST_COMMON_LOW + 0x20
      TER_LOWER_FIRST_COMMON_HIGH = TER_LOWER_FIRST_COMMON_LOW + 0x40
      TER_LOWER_FIRST_COMMON_MAX_COUNT = 0x21

      # Tertiary with case, upperFirst: Compress up to 33 common weights as 85..A5 or A5..C5.
      TER_UPPER_FIRST_COMMON_LOW = COMMON_BYTE + 0x80
      TER_UPPER_FIRST_COMMON_MIDDLE = TER_UPPER_FIRST_COMMON_LOW + 0x20
      TER_UPPER_FIRST_COMMON_HIGH = TER_UPPER_FIRST_COMMON_LOW + 0x40
      TER_UPPER_FIRST_COMMON_MAX_COUNT = 0x21

      # Quaternary level: Compress up to 113 common weights as 1C..8C or 8C..FC.
      QUAT_COMMON_LOW = 0x1C
      QUAT_COMMON_MIDDLE = QUAT_COMMON_LOW + 0x70
      QUAT_COMMON_HIGH = QUAT_COMMON_LOW + 0xE0
      QUAT_COMMON_MAX_COUNT = 0x71
      # Primary weights shifted to quaternary level must be encoded with
      # a lead byte below the common-weight compression range.
      QUAT_SHIFTED_LIMIT_BYTE = QUAT_COMMON_LOW - 1 # 0x1b

      MERGE_SEPARATOR_PRIMARY = 0x02000000  # U+FFFE
      NO_CE_PRIMARY = 1  # not a left-adjusted weight
      NO_CE_WEIGHT16 = 0x0100  # weight of LEVEL_SEPARATOR_BYTE
      NO_CE = 0x101000100


      class << self
        def sort_key_for(locale, str, **options)
          iterator = TwitterCldr::CollationElementIterator.new(locale, str)
          new(locale, iterator, **options).sort_key
        end
      end

      attr_reader :bytes_array
      attr_reader :locale, :iterator, :maximum_level

      def initialize(locale, iterator, **options)
        @locale = locale
        @iterator = iterator
        @maximum_level = options[:maximum_level] || 3
      end

      def sort_key
        reset

        loop do
          ce = @iterator.next_ce
          primary_weight = ce >> 32 & 0xFFFF_FFFF

          if primary_weight < variable_top && primary_weight > MERGE_SEPARATOR_PRIMARY
            primary_weight, ce = collect_variable_ce_bytes(primary_weight, ce)
          end

          # ce could be primary ignorable, or NO_CE, or the merge separator,
          # or a regular primary CE, but it is not variable.
          # If ce==NO_CE, then write nothing for the primary level but
          # terminate compression on all levels and then exit the loop.
          if primary_weight > NO_CE_PRIMARY && @maximum_level >= 1
            collect_primary_bytes(primary_weight)
          end

          lower32 = ce & 0xFFFF_FFFF

          # completely ignorable, no secondary/case/tertiary/quaternary
          next if lower32 == 0

          collect_secondary_bytes(lower32, primary_weight)  if @maximum_level >= 2
          collect_case_level_bytes(lower32, primary_weight) if settings.case_level?
          collect_tertiary_bytes(lower32)                   if @maximum_level >= 3
          collect_quaternary_bytes(lower32)                 if @maximum_level == 4

          if ((lower32 >> 24) & 0xFFFF_FFFF) == LEVEL_SEPARATOR_BYTE
            break
          end # ce == NO_CE
        end

        append_level_bytes

        @bytes_array
      end

      private

      def reset
        @bytes_array = []

        @cases = []
        @secondaries = []
        @tertiaries = []
        @quaternaries = []

        @prev_reordered_primary = 0  # 0==no compression
        @common_cases = 0
        @common_secondaries = 0
        @common_tertiaries = 0
        @common_quaternaries = 0

        @prev_secondary = 0
        @sec_segment_start = 0
      end

      def collect_variable_ce_bytes(primary_weight, ce)
        # shift variable CE to quaternary level.
        # Ignore all following primary ignorables, and shift further variable CEs.

        collect_common_quaternary_bytes do |common|
          QUAT_COMMON_LOW + common
        end

        @common_quaternaries = 0

        loop do
          if @maximum_level == 4
            primary_weight = reorder(primary_weight) if reorder?

            if (primary_weight >> 24) & 0xFFFF_FFFF >= QUAT_SHIFTED_LIMIT_BYTE
              # Prevent shifted primary lead bytes from
              # overlapping with the common compression range.
              @quaternaries << QUAT_SHIFTED_LIMIT_BYTE
            end

            @quaternaries += integer_to_bytes_array(primary_weight)
          end

          loop do
            ce = @iterator.next_ce
            primary_weight = (ce >> 32) & 0xFFFF_FFFF
            break if primary_weight != 0
          end

          break if primary_weight >= variable_top || primary_weight <= MERGE_SEPARATOR_PRIMARY
        end

        [primary_weight, ce]
      end

      def collect_primary_bytes(primary_weight)
        # Test the un-reordered primary for compressibility.
        is_compressible = compressible?((primary_weight >> 24) & 0xFFFF_FFFF)
        primary_weight = reorder(primary_weight) if reorder?
        p1 = (primary_weight >> 24) & 0xFFFF_FFFF

        if !is_compressible || p1 != ((@prev_reordered_primary >> 24) & 0xFFFF_FFFF)
          if @prev_reordered_primary != 0
            if primary_weight < @prev_reordered_primary
              # No primary compression terminator
              # at the end of the level or merged segment.
              if p1 > MERGE_SEPARATOR_BYTE
                @bytes_array << PRIMARY_COMPRESSION_LOW_BYTE
              end
            else
              @bytes_array << PRIMARY_COMPRESSION_HIGH_BYTE
            end
          end

          @bytes_array << p1

          if is_compressible
            @prev_reordered_primary = primary_weight
          else
            @prev_reordered_primary = 0
          end
        end

        @bytes_array += primary_bytes_for(primary_weight)
      end

      def collect_secondary_bytes(lower32, primary_weight)
        secondary_weight = (lower32 >> 16) & 0xFFFF_FFFF

        if secondary_weight == 0
          # secondary ignorable
        elsif secondary_weight == COMMON_WEIGHT16 && (!backward_secondary? || primary_weight != MERGE_SEPARATOR_PRIMARY)
          # s is a common secondary weight, and
          # backwards-secondary is off or the ce is not the merge separator.
          @common_secondaries += 1
        elsif backward_secondary?
          collect_secondary_bytes_backward(secondary_weight, primary_weight)
        else
          collect_secondary_bytes_forward(secondary_weight)
        end
      end

      def collect_secondary_bytes_forward(secondary_weight)
        collect_common_secondary_bytes do |common|
          if secondary_weight < COMMON_WEIGHT16
            SEC_COMMON_LOW + common
          else
            SEC_COMMON_HIGH - common
          end
        end

        @common_secondaries = 0
        @secondaries += weight16_to_bytes_array(secondary_weight)
      end

      def collect_secondary_bytes_backward(secondary_weight, primary_weight)
        if @common_secondaries != 0
          # Append reverse weights. The level will be re-reversed later.
          remainder = (@common_secondaries - 1) % SEC_COMMON_MAX_COUNT

          b = if @prev_secondary < COMMON_WEIGHT16
            SEC_COMMON_LOW + remainder
          else
            SEC_COMMON_HIGH - remainder
          end

          @secondaries << b
          @common_secondaries -= remainder

          collect_common_secondary_bytes
          @common_secondaries = 0
        end

        if 0 < primary_weight && primary_weight <= MERGE_SEPARATOR_PRIMARY
          # The backwards secondary level compares secondary weights backwards
          # within segments separated by the merge separator (U+FFFE).
          secs = @secondaries
          last = @secondaries.size - 1

          while @sec_segment_start < last
            b = secs[@sec_segment_start]
            secs[@sec_segment_start] = secs[last]
            @sec_segment_start += 1
            secs[last] = b
            last -= 1
          end

          if primary_weight == NO_CE_PRIMARY
            @secondaries << LEVEL_SEPARATOR_BYTE
          else
            @secondaries << MERGE_SEPARATOR_BYTE
          end

          @prev_secondary = 0
          @sec_segment_start = @secondaries.size
        else
          @secondaries += weight16_to_bytes_array(secondary_weight).reverse
          @prev_secondary = secondary_weight
        end
      end

      def collect_case_level_bytes(lower32, primary_weight)
        should_ignore = if settings.strength == PRIMARY
          # Primary + caseLevel: Ignore case level weights of primary ignorables.
          primary_weight == 0
        else
          # Otherwise: Ignore case level weights of secondary ignorables.
          ((lower32 >> 16) & 0xFFFF_FFFFF) == 0
        end

        return if should_ignore

        case_weight = (lower32 >> 8) & 0xFF # case bits & tertiary lead byte
        # assert ((case_weight & 0xc0) != 0xc0)

        if (case_weight & 0xC0) == 0 && case_weight > LEVEL_SEPARATOR_BYTE
          @common_cases += 1
        else
          if settings.lowercase_first?
            collect_lowercase_bytes(case_weight)

            if case_weight > LEVEL_SEPARATOR_BYTE
              case_weight = (CASE_LOWER_FIRST_COMMON_HIGH + ((case_weight >> 6) & 0xFFFF_FFFF)) << 4 # 14 or 15
            end
          else
            collect_uppercase_bytes(case_weight)

            if case_weight > LEVEL_SEPARATOR_BYTE
              case_weight = (CASE_UPPER_FIRST_COMMON_LOW - ((case_weight >> 6) & 0xFFFF_FFFF)) << 4 # 2 or 1
            end
          end

          # case_weight is a separator byte 01,
          # or a left-shifted nibble 0x10, 0x20, ... 0xf0.
          @cases << case_weight
        end
      end

      def collect_lowercase_bytes(case_weight)
        # lowerFirst: Compress common weights to nibbles 1..7..13, mixed=14,
        # upper=15.
        # If there are only common (=lowest) weights in the whole level,
        # then we need not write anything.
        # Level length differences are handled already on the next-higher level.
        if @common_cases != 0 && (case_weight > LEVEL_SEPARATOR_BYTE || !@cases.empty?)
          collect_common_case_level_bytes(:lower_first) do |common|
            b = if case_weight <= LEVEL_SEPARATOR_BYTE
              CASE_LOWER_FIRST_COMMON_LOW + common
            else
              CASE_LOWER_FIRST_COMMON_HIGH - common
            end

            b << 4
          end

          @common_cases = 0
        end
      end

      def collect_uppercase_bytes(_case_weight)
        # upperFirst: Compress common weights to nibbles 3..15, mixed=2,
        # upper=1.
        # The compressed common case weights only go up from the "low" value
        # because with upperFirst the common weight is the highest one.

        collect_common_case_level_bytes(:upper_first) do |common|
          (CASE_UPPER_FIRST_COMMON_LOW + common) << 4
        end

        @common_cases = 0
      end

      def collect_tertiary_bytes(lower32)
        tertiary_weight = lower32 & tertiary_mask
        # assert ((lower32 & 0xc000) != 0xc000);

        if tertiary_weight == COMMON_WEIGHT16
          @common_tertiaries += 1
        elsif (tertiary_mask & 0x8000) == 0
          collect_tertiary_bytes_without_case(tertiary_weight)
        elsif settings.lowercase_first?
          collect_lowercase_tertiary_bytes(tertiary_weight)
        else
          collect_uppercase_tertiary_bytes(lower32, tertiary_weight)
        end
      end

      def collect_tertiary_bytes_without_case(tertiary_weight)
        # Tertiary weights without case bits.
        # Move lead bytes 06..3F to C6..FF for a large common-weight range.
        collect_common_tertiary_bytes(:ter_only) do |common|
          if tertiary_weight < COMMON_WEIGHT16
            TER_ONLY_COMMON_LOW + common
          else
            TER_ONLY_COMMON_HIGH - common
          end
        end

        @common_tertiaries = 0

        if tertiary_weight > COMMON_WEIGHT16
          tertiary_weight += 0xC000
        end

        @tertiaries += weight16_to_bytes_array(tertiary_weight)
      end

      def collect_lowercase_tertiary_bytes(tertiary_weight)
        # Tertiary weights with caseFirst=lowerFirst.
        # Move lead bytes 06..BF to 46..FF for the common-weight range.
        collect_common_tertiary_bytes(:lower_first) do |common|
          if tertiary_weight < COMMON_WEIGHT16
            TER_LOWER_FIRST_COMMON_LOW + common
          else
            TER_LOWER_FIRST_COMMON_HIGH - common
          end
        end

        @common_tertiaries = 0

        if tertiary_weight > COMMON_WEIGHT16
          tertiary_weight += 0x4000
        end

        @tertiaries += weight16_to_bytes_array(tertiary_weight)
      end

      def collect_uppercase_tertiary_bytes(lower32, tertiary_weight)
        # Tertiary weights with caseFirst=upperFirst.
        # Do not change the artificial uppercase weight of a tertiary CE (0.0.ut),
        # to keep tertiary CEs well-formed.
        # Their case+tertiary weights must be greater than those of
        # primary and secondary CEs.
        #
        # Separator         01 -> 01      (unchanged)
        # Lowercase     02..04 -> 82..84  (includes uncased)
        # Common weight     05 -> 85..C5  (common-weight compression range)
        # Lowercase     06..3F -> C6..FF
        # Mixed case    42..7F -> 42..7F
        # Uppercase     82..BF -> 02..3F
        # Tertiary CE   86..BF -> C6..FF
        if tertiary_weight <= NO_CE_WEIGHT16
          # Keep separators unchanged.
        elsif ((lower32 >> 16) & 0xFFFF_FFFF) != 0
          # Invert case bits of primary & secondary CEs.
          tertiary_weight ^= 0xC000

          if tertiary_weight < (TER_UPPER_FIRST_COMMON_HIGH << 8)
            tertiary_weight -= 0x4000
          end
        else
          # Keep uppercase bits of tertiary CEs.
          # assert (0x8600 <= tertiary_weight && tertiary_weight <= 0xbfff);
          tertiary_weight += 0x4000
        end

        collect_common_tertiary_bytes(:upper_first) do |common|
          if tertiary_weight < (TER_UPPER_FIRST_COMMON_LOW << 8)
            TER_UPPER_FIRST_COMMON_LOW + common
          else
            TER_UPPER_FIRST_COMMON_HIGH - common
          end
        end

        @common_tertiaries = 0
        @tertiaries += weight16_to_bytes_array(tertiary_weight)
      end

      def collect_quaternary_bytes(lower32)
        q = lower32 & 0xFFFF

        if (q & 0xC0) == 0 && q > NO_CE_WEIGHT16
          @common_quaternaries += 1
        elsif q == NO_CE_WEIGHT16 && !settings.alternate_handling? && @quaternaries.empty?
          # If alternate=non-ignorable and there are only common quaternary weights,
          # then we need not write anything.
          # The only weights greater than the merge separator and less than the common
          # weight
          # are shifted primary weights, which are not generated for
          # alternate=non-ignorable.
          # There are also exactly as many quaternary weights as tertiary weights,
          # so level length differences are handled already on tertiary level.
          # Any above-common quaternary weight will compare greater regardless.
          @quaternaries << LEVEL_SEPARATOR_BYTE
        else
          q = if q == NO_CE_WEIGHT16
            LEVEL_SEPARATOR_BYTE
          else
            0xFC + (((q >> 6) & 0xFFFF_FFFF) & 3)
          end

          collect_common_quaternary_bytes do |common|
            if q < QUAT_COMMON_LOW
              QUAT_COMMON_LOW + common
            else
              QUAT_COMMON_HIGH - common
            end
          end

          @common_quaternaries = 0
          @quaternaries << q
        end
      end

      def collect_common_secondary_bytes(&block)
        collect_common_bytes(@secondaries, @common_secondaries, SEC_COMMON_MAX_COUNT, SEC_COMMON_MIDDLE, &block)
      end

      def collect_common_case_level_bytes(mode, &block)
        case mode
          when :lower_first
            collect_common_bytes(@cases, @common_cases, CASE_LOWER_FIRST_COMMON_MAX_COUNT, CASE_LOWER_FIRST_COMMON_MIDDLE, &block)
          when :upper_first
            collect_common_bytes(@cases, @common_cases, CASE_UPPER_FIRST_COMMON_MAX_COUNT, CASE_UPPER_FIRST_COMMON_LOW << 4, &block)
          else
            raise "Invalid case level mode '#{mode}'"
        end
      end

      def collect_common_tertiary_bytes(mode, &block)
        case mode
          when :ter_only
            collect_common_bytes(@tertiaries, @common_tertiaries, TER_ONLY_COMMON_MAX_COUNT, TER_ONLY_COMMON_MIDDLE, &block)
          when :lower_first
            collect_common_bytes(@tertiaries, @common_tertiaries, TER_LOWER_FIRST_COMMON_MAX_COUNT, TER_LOWER_FIRST_COMMON_MIDDLE, &block)
          when :upper_first
            collect_common_bytes(@tertiaries, @common_tertiaries, TER_UPPER_FIRST_COMMON_MAX_COUNT, TER_UPPER_FIRST_COMMON_MIDDLE, &block)
          else
            raise "Invalid tertiary mode '#{mode}'"
        end
      end

      def collect_common_quaternary_bytes(&block)
        collect_common_bytes(@quaternaries, @common_quaternaries, QUAT_COMMON_MAX_COUNT, QUAT_COMMON_MIDDLE, &block)
      end

      def collect_common_bytes(accum, common_count, max_count, middle)
        return if common_count == 0

        common_count -= 1

        while common_count >= max_count
          accum << middle
          common_count -= max_count
        end

        if block_given?
          accum << yield(common_count)
        end
      end

      def append_level_bytes
        if @maximum_level >= 2
          @bytes_array << LEVEL_SEPARATOR_BYTE
          @bytes_array += @secondaries[0..-2]
        end

        append_case_level_bytes if settings.case_level?

        if @maximum_level >= 3
          @bytes_array << LEVEL_SEPARATOR_BYTE
          @bytes_array += @tertiaries[0..-2]
        end

        if @maximum_level == 4
          @bytes_array << LEVEL_SEPARATOR_BYTE
          @bytes_array += @quaternaries[0..-2]
        end
      end

      def append_case_level_bytes
        @bytes_array << LEVEL_SEPARATOR_BYTE

        # Write pairs of nibbles as bytes, except separator bytes as themselves.
        b = 0

        @cases[0..-2].each do |c|
          # assert ((c & 0xf) == 0 && c != 0)
          if b == 0
            b = c
          else
            @bytes_array << (b | ((c >> 4) & 0xF))
            b = 0
          end
        end

        if b != 0
          @bytes_array << b
        end
      end

      def compressible?(weight)
        collation_data.compressible_bytes[weight]
      end

      def weight16_to_bytes_array(number)
        b0 = (number >> 8) & 0xFF
        b1 = number & 0xFF
        bytes = [b0]
        (bytes << b1) if b1 != 0
        bytes
      end

      def integer_to_bytes_array(number)
        bytes = []

        while number > 0
          bytes.unshift(number & 0xFF)
          number >>= 8
        end

        bytes
      end

      def primary_bytes_for(primary_weight)
        bytes = integer_to_bytes_array(primary_weight)

        p2 = (primary_weight >> 16) & 0xFF
        p3 = (primary_weight >> 8) & 0xFF
        bytes = []

        if p2 != 0
          if p3 == 0
            bytes << p2
          elsif primary_weight == 0
            bytes << p2
            bytes << p3
          else
            bytes << p2
            bytes << p3
            bytes << (primary_weight & 0xFF)
          end
        end

        bytes
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

      def tertiary_mask
        settings.tertiary_mask
      end

      def reorder?
        settings.has_reordering?
      end

      def backward_secondary?
        settings.backward_secondary?
      end

      def variable_top
        @variable_top ||= if settings.alternate_handling?
          settings.variable_top + 1
        else
          0
        end
      end

      def settings
        collation_data.settings
      end

      def collation_data
        @collation_data ||= TailoredCollationData.for_locale(locale)
      end
    end
  end
end
