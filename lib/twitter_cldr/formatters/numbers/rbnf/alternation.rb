# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Formatters
    module Rbnf

      class Alternation
        attr_reader :left, :right

        def initialize
          @left = []
          @right = []
        end

        def type
          :alternation
        end

        def value
          "#{[*left.map(&:value), *right.map(&:value)].join}"
        end

        def substitution_count
          @substitution_count ||=
            left.count { |token| token.is_a?(Substitution) } +
            right.count { |token| token.is_a?(Substitution) }
        end
      end

    end
  end
end
