# frozen_string_literal: true

module TwitterCldr
  module Collation
    class CollationElementIterator
      CONTEXT_CE = -1
      NO_CE = 0x101000100

      attr_reader :locale

      def initialize(locale = TwitterCldr.locale, str)
        @locale = locale == :root ? locale : TwitterCldr.normalize_locale(locale)
        @str = str

        reset
      end

      def reset
        @pos = 0
        @str = TwitterCldr::Normalization.normalize(@str, using: :nfd)
        @cursor = Cursor.new(TwitterCldr::Utils::CodePoints.from_string(@str))
        @buffer = []
      end

      def next_ce
        populate if @pos >= @buffer.size

        if @buffer[@pos] == NO_CE
          NO_CE
        else
          @buffer[@pos].tap do
            @pos += 1
          end
        end
      end

      def set_current(ce)
        @buffer[@pos - 1] = ce
      end

      def at(index)
        @buffer[index]
      end

      def next_ce?
        @buffer[@pos] != NO_CE
      end

      private

      def settings
        collation_data.settings
      end

      def collation_data
        @collation_data ||= TailoredCollationData.for_locale(locale)
      end

      def populate
        cp = @cursor.next_code_point

        if cp < 0
          @buffer << NO_CE
          return
        end

        @buffer += resolve_cp(cp, @cursor)
      end

      def resolve_cp(cp, cursor)
        suffixes = collation_data.suffixes_for(cp)

        case suffixes&.[](:value)
          when CONTEXT_CE
            context = collation_data.context_for(cp)
            resolve_context(context, cursor)
          else
            suffixes&.[](:value) || [0]
        end
      end

      def resolve_context(context, cursor)
        if context.forward?
          get_ce_from_contraction(context, cursor)
        else
          get_ce_from_prefix(context, cursor)
        end
      end

      def get_ce_from_contraction(contraction, cursor)
        default_ce = contraction.default_ce
        next_cp = nil

        if cursor.skipped.nil? && cursor.num_cp_fwd < 0
          # Some portion of next_ce_from_contraction pulled out here as an ASCII fast path,
          # avoiding the function call and the cursor.next_skipped_code_point overhead.
          next_cp = cursor.next_code_point

          if next_cp < 0
            # No more text.
            return default_ce
          elsif contraction.next_ccc? && combining_class_for(next_cp) == "0"
            # All contraction suffixes start with characters with lccc!=0
            # but the next code point has lccc==0.
            cursor.backward_num_code_points(1)
            return default_ce
          end
        else
          next_cp = cursor.next_skipped_code_point

          if next_cp < 0
            # No more text.
            return default_ce
          elsif contraction.next_ccc? && combining_class_for(next_cp) == "0"
            # All contraction suffixes start with characters with lccc!=0
            # but the next code point has lccc==0.
            cursor.backward_num_skipped(1)
            return default_ce
          end
        end

        ces = next_ce_from_contraction(contraction, cursor)

        if ces.empty?
          # CEs from a discontiguous contraction plus the skipped combining marks
          # have been appended already.
          return default_ce
        end

        ces
      end

      def next_ce_from_contraction(contraction, cursor)
        # Number of code points read beyond the original code point.
        # Needed for discontiguous contraction matching.
        look_ahead = 1

        # Number of code points read since the last match (initially only c).
        since_match = 1

        # Normally we only need a contiguous match,
        # and therefore need not remember the suffixes state from before a mismatch for retrying.
        # If we are already processing skipped combining marks, then we do track the state.
        if cursor.skipped && !cursor.skipped.empty?
          cursor.skipped.trie_node = contraction.suffixes
        end

        match = contraction.suffixes[:children][cursor.current]
        ces = []

        loop do
          next_cp = nil

          if match&.[](:value)
            ces = match[:value]

            if (!match[:children] || match[:children].empty?) || (cp = cursor.next_skipped_code_point) < 0
              return ces
            end

            if cursor.skipped && !cursor.skipped.empty?
              cursor.skipped.trie_node = contraction.suffixes
            end

            since_match = 1
          elsif !match || (next_cp = cursor.next_skipped_code_point) < 0
            # No match for c, or partial match (match is nil) and no further text.
            # Back up if necessary, and try a discontiguous contraction.
            # Discontiguous contraction matching extends an existing match.
            # If there is no match yet, then there is nothing to do.
            if contraction.trailing_ccc? && (!contraction.single_cp_no_match? || since_match < look_ahead)
              # The last character of at least one suffix has lccc!=0,
              # allowing for discontiguous contractions.
              # UCA S2.1.1 only processes non-starters immediately following
              # "a match in the table" (sinceMatch=1).
              if since_match > 1
                # Return to the state after the last match.
                # (Return to sinceMatch=0 and re-fetch the first partially-matched
                # character.)
                cursor.backward_num_skipped(since_match)

                cp = cursor.next_skipped_code_point
                look_ahead -= since_match - 1
                since_match = 1
              end

              if combining_class_for(cursor.current) != "0"
                return next_ce_from_discontiguous_contraction(contraction, cursor, look_ahead, ces)
              end
            end

            break
          else
            # Continue after partial match (BytesTrie.Result.NO_VALUE) for c.
            # It does not have a result value, therefore it is not itself "a match in the
            # table".
            # If a partially-matched c has ccc!=0 then
            # it might be skipped in discontiguous contraction.
            cp = next_cp
            since_match += 1
          end

          look_ahead += 1
          match = match[:children][cp]
        end

        cursor.backward_num_skipped(since_match)

        ces
      end

      def next_ce_from_discontiguous_contraction(contraction, cursor, look_ahead, ces)
        # UCA section 3.3.2 Contractions:
        # Contractions that end with non-starter characters
        # are known as discontiguous contractions.
        # ... discontiguous contractions must be detected in input text
        # whenever the final sequence of non-starter characters could be rearranged
        # so as to make a contiguous matching sequence that is canonically equivalent.

        # UCA: http:#www.unicode.org/reports/tr10/#S2.1
        # S2.1 Find the longest initial substring S at each point that has a match in the table.
        # S2.1.1 If there are any non-starters following S, process each non-starter C.
        # S2.1.2 If C is not blocked from S, find if S + C has a match in the table.
        #     Note: A non-starter in a string is called blocked
        #     if there is another non-starter of the same canonical combining class or zero
        #     between it and the last character of canonical combining class 0.
        # S2.1.3 If there is a match, replace S by S + C, and remove C.

        cp = cursor.current

        # First: Is a discontiguous contraction even possible?
        next_cp = cursor.next_skipped_code_point

        if next_cp < 0
          # No further text.
          cursor.backward_num_skipped(1)
          return []
        end

        look_ahead += 1

        prev_cc = combining_class_for(cp)
        next_cc = combining_class_for(next_cp)

        if next_cc == "0"
          # The next code point after c is a starter (S2.1.1 "process each non-starter").
          cursor.backward_num_skipped(2)
          return ces
        end

        node = contraction.suffixes

        # We have read and matched (look_ahead - 2) code points,
        # read non-matching c and peeked ahead at next_cp.
        # Return to the state before the mismatch and continue matching with next_cp.
        if cursor.skipped.nil? || cursor.skipped.empty?
          if cursor.skipped.nil?
            cursor.skipped = SkippedState.new
          end

          if look_ahead > 2
            # Replay the partial match so far.
            cursor.backward_num_code_points(look_ahead)
            node = node[:children][cursor.next_code_point]

            3.upto(look_ahead - 1) do |i|
              node = node[:children][cursor.next_code_point]
            end

            # Skip c (which did not match) and nextCp (which we will try now).
            cursor.forward_num_code_points(2)
          end

          cursor.skipped.trie_node = node
        else
          # Reset to the trie state before the failed match of c.
          cursor.skipped.trie_node = contraction.suffixes
        end

        cursor.skipped.set_first_skipped(cp)

        # Number of code points read since the last match (at this point: c and nextCp).
        since_match = 2
        c = next_cp

        ces = nil

        loop do
          # "If C is not blocked from S, find if S + C has a match in the table." (S2.1.2)
          if prev_cc < next_cc && (match = node[:children][c])&.[](:value)
            # "If there is a match, replace S by S + C, and remove C." (S2.1.3)
            # Keep prevCC unchanged.
            ces = match[:value]

            since_match = 0
            cursor.skipped.record_match

            if !match[:children] || match[:children].empty?
              break
            end

            cursor.skipped.trie_node = match
            node = match
          else
            # No match for "S + C", skip C.
            cursor.skipped.skip(c)
            node = cursor.skipped.trie_node
            prev_cc = next_cc
          end

          if (c = cursor.next_skipped_code_point) < 0
            break
          end

          since_match += 1
          next_cc = combining_class_for(c)

          if next_cc == "0"
            # The next code point after c is a starter (S2.1.1 "process each non-starter").
            break
          end
        end

        ces = ces ? ces.dup : []

        cursor.backward_num_skipped(since_match)
        is_top_discontiguous = cursor.skipped.empty?
        cursor.skipped.replace_match

        if is_top_discontiguous && !cursor.skipped.empty?
          # We did get a match after skipping one or more combining marks,
          # and we are not in a recursive discontiguous contraction.
          # Append CEs from the contraction CE and then from the combining
          # marks that we skipped before the match.

          while cursor.skipped.next?
            c = cursor.skipped.get_next

            # Fetch CEs for skipped combining marks from the normal data, with fallback,
            # rather than from the CollationData where we found the contraction.
            ces.concat(resolve_cp(c, cursor))

            # Note: A nested discontiguous-contraction match
            # replaces consumed combining marks with newly skipped ones
            # and resets the reading position to the beginning.
          end

          cursor.skipped.clear
        end

        ces
      end

      def get_ce_from_prefix(prefix, cursor)
        # Number of code points read before the original code point.
        look_behind = 0
        node = prefix.suffixes
        ces = prefix.default_ce
        return ces unless node

        loop do
          c = cursor.previous_code_point
          break if c < 0

          look_behind += 1
          node = node[:children][c]

          if node&.[](:value)
            ces = node[:value]
          end

          break if !node
          break if !node[:children]
          break if node[:children].empty?
        end

        cursor.forward_num_code_points(look_behind)
        ces
      end

      def combining_class_for(cp)
        combining_class_cache[cp] ||= TwitterCldr::Shared::CodePoint.get(cp).combining_class
      end

      def combining_class_cache
        @@combining_class_cache ||= {}
      end
    end
  end
end
