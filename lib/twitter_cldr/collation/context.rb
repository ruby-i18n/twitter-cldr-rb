# frozen_string_literal: true

module TwitterCldr
  module Collation
    class Context
      attr_reader :default_ce, :suffixes, :direction, :single_cp_no_match, :next_ccc, :trailing_ccc

      def initialize(**data)
        @default_ce = data[:default_ce]
        @suffixes = data[:suffixes]
        @direction = data[:direction]
        @single_cp_no_match = data[:single_cp_no_match]
        @next_ccc = data[:next_ccc]
        @trailing_ccc = data[:trailing_ccc]
      end

      alias single_cp_no_match? single_cp_no_match
      alias next_ccc? next_ccc
      alias trailing_ccc? trailing_ccc

      def forward?
        direction == :forward
      end
    end
  end
end
