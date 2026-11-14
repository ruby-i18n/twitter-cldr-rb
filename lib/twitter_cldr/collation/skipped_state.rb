# frozen_string_literal: true

module TwitterCldr
  module Collation
    class SkippedState
      # Combining marks skipped in previous discontiguous-contraction matching.
      # After that discontiguous contraction was completed, we start reading them from here.
      attr_reader :old_buffer

      # Combining marks newly skipped in current discontiguous-contraction matching.
      # These might have been read from the normal text or from the oldBuffer.
      attr_reader :new_buffer

      # Reading index in oldBuffer,
      # or counter for how many code points have been read beyond oldBuffer
      # (pos - old_buffer.length).
      attr_reader :pos

      # new_buffer.length at the time of the last matching character.
      # When a partial match fails, we back out skipped and partial-matching input characters.
      attr_reader :skip_length_at_match

      attr_accessor :trie_node

      def initialize
        @old_buffer = []
        @new_buffer = []
        @pos = 0
        @skip_length_at_match = 0
      end

      def clear
        old_buffer.clear
        @pos = 0

        # The new_buffer is reset by set_first_skipped.
      end

      def empty?
        old_buffer.length == 0
      end

      def next?
        pos < old_buffer.length
      end

      # Requires hasNext().
      def get_next
        c = old_buffer[pos]
        @pos += 1
        c
      end

      # Accounts for one more input code point read beyond the end of the marks buffer.
      def inc_beyond
        raise "Buffer not at end" if next?
        @pos += 1
      end

      # Goes backward through the skipped-marks buffer.
      # Returns the number of code points read beyond the skipped marks
      # that need to be backtracked through normal input.
      def backward_num_code_points(n)
        length = old_buffer.length
        beyond = pos - length

        if beyond > 0
          if beyond >= n
            # Not back far enough to re-enter the oldBuffer.
            @pos -= n
            n
          else
            # Back out all beyond-oldBuffer code points and re-enter the buffer.
            @pos = old_buffer.offset_by_code_points(length, beyond - n)
            beyond
          end
        else
          # Go backwards from inside the oldBuffer.
          @pos = old_buffer.offset_by_code_points(pos, -n)
          0
        end
      end

      def set_first_skipped(c)
        @skip_length_at_match = 0
        new_buffer.clear
        new_buffer << c
      end

      def skip(c)
        new_buffer << c
      end

      def record_match
        @skip_length_at_match = new_buffer.length
      end

      # Replaces the characters we consumed with the newly skipped ones.
      def replace_match
        # Note: UnicodeString.replace() pins pos to at most length().
        old_length = old_buffer.length

        if pos > old_length
          @pos = old_length
        end

        old_buffer.shift(pos)
        old_buffer.insert(0, *new_buffer.slice(0...skip_length_at_match))

        @pos = 0
      end
    end
  end
end
