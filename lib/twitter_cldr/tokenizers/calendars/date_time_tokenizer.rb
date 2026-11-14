# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Tokenizers
    module DateTimeTokenizer

      class << self
        def tokenize(pattern)
          tokenizer.tokenize(pattern)
        end

        def tokenizer
          @tokenizer ||= Tokenizer.new([
            TokenRecognizer.new(:date_placeholder, /\{\{date\}\}/),
            TokenRecognizer.new(:time_placeholder, /\{\{time\}\}/),
            TokenRecognizer.new(:pos_placeholder0, /\{0\}/),
            TokenRecognizer.new(:pos_placeholder1, /\{1\}/),
            TokenRecognizer.new(:pos_placeholder2, /\{2\}/),
            TokenRecognizer.new(:date_pattern, /^(G{1,5}|y+|Y+|Q{1,4}|q{1,5}|M{1,5}|L{1,5}|d{1,2}|F{1}|E{1,5}|e{1,5}|c{1,5}|w{1,2}|W{1})/),
            TokenRecognizer.new(:time_pattern, /^(a{1}|b{1,5}|B{1,5}|h{1,2}|H{1,2}|K{1,2}|k{1,2}|m{1,2}|s{1,2}|S+|z{1,4}|Z{1,4}V{1,4}|v{1,4}|z{1,4}|Z{1,5}|O|O{4}|V{1,4}|X{1,5}|x{1,5}|j{1,6}|J{1,2})/),
            TokenRecognizer.new(:plaintext, /'.*'/),
            TokenRecognizer.new(:plaintext, //)
          ], /(\{\{?[^\}]+\}?\}|\s*\'[\w\s-]+\'\s*|G{1,5}|y+|Y+|Q{1,4}|q{1,5}|M{1,5}|L{1,5}|d{1,2}|F{1}|E{1,5}|e{1,5}|c{1,5}|w{1,2}|W{1}|a{1}|B{1,5}|h{1,2}|H{1,2}|K{1,2}|k{1,2}|m{1,2}|s{1,2}|S+|z{1,4}|Z{1,4}V{1,4}|v{1,4}|z{1,4}|Z{1,5}|O|O{4}|V{1,4}|X{1,5}|x{1,5}|j{1,6})/)
        end
      end

    end
  end
end
