# frozen_string_literal: true

module TwitterCldr
  module Collation
    class Cursor
      attr_reader :cps, :pos, :num_cp_fwd
      attr_accessor :skipped

      def initialize(cps)
        @cps = cps
        @pos = -1
        @num_cp_fwd = -1
      end

      def current
        cps[pos]
      end

      def backward_num_skipped(n)
        if skipped && !skipped.empty?
          n = skipped.backward_num_code_points(n)
        end

        @pos -= n

        if num_cp_fwd >= 0
          @num_cp_fwd += n
        end
      end

      def forward_num_code_points(n)
        @pos += n
        @pos = cps.size - 1 if @pos >= cps.size
        nil
      end

      def backward_num_code_points(n)
        @pos -= n
        @pos = 0 if @pos < 0
        nil
      end

      def next_skipped_code_point
        return skipped.get_next if skipped && skipped.next?
        return -1 if num_cp_fwd == 0 # SENTINEL_CP

        c = next_code_point

        if skipped && !skipped.empty? && c >= 0
          skipped.inc_beyond
        end

        if num_cp_fwd > 0 && c >= 0
          @num_cp_fwd -= 1
        end

        c
      end

      def next_code_point
        return -1 if @pos + 1 >= cps.size

        @pos += 1
        current
      end

      def previous_code_point
        return -1 if @pos <= 0

        @pos -= 1
        current
      end

      def eos?
        pos >= cps.size
      end
    end
  end
end
