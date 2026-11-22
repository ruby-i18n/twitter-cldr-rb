# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

describe TwitterCldr::Tokenizers::DateTimeTokenizer do
  describe "#tokenize" do
    it "should tokenize plaintext segments correctly" do
      got = described_class.tokenize("EEEE, d 'de' MMMM 'de' y")
      expected  = [
        { value: "EEEE", type: :date_pattern },
        { value: ", ", type: :plaintext },
        { value: "d", type: :date_pattern },
        { value: " 'de' ", type: :plaintext },
        { value: "MMMM", type: :date_pattern },
        { value: " 'de' ", type: :plaintext },
        { value: "y", type: :date_pattern }
      ]
      check_token_list(got, expected)
    end

    it "should tokenize patterns with non-latin characters correctly (i.e. Japanese)" do
      got = described_class.tokenize("y年M月d日EEEE")
      expected  = [
        { value: "y", type: :date_pattern },
        { value: "年", type: :plaintext },
        { value: "M", type: :date_pattern },
        { value: "月", type: :plaintext },
        { value: "d", type: :date_pattern },
        { value: "日", type: :plaintext },
        { value: "EEEE", type: :date_pattern }
      ]
      check_token_list(got, expected)
    end

    it "should tokenize a time string correctly (i.e. German)" do
      got = described_class.tokenize("HH:mm:ss zzzz")
      expected  = [
        { value: "HH", type: :time_pattern },
        { value: ":", type: :plaintext },
        { value: "mm", type: :time_pattern },
        { value: ":", type: :plaintext },
        { value: "ss", type: :time_pattern },
        { value: " ", type: :plaintext },
        { value: "zzzz", type: :time_pattern }
      ]
      check_token_list(got, expected)
    end

    it "should tokenize patterns with non-latin characters correctly" do
      got = described_class.tokenize("a h시 m분 s초 zzzz")
      expected  = [
        { value: "a", type: :time_pattern },
        { value: " ", type: :plaintext },
        { value: "h", type: :time_pattern },
        { value: "시 ", type: :plaintext },
        { value: "m", type: :time_pattern },
        { value: "분 ", type: :plaintext },
        { value: "s", type: :time_pattern },
        { value: "초 ", type: :plaintext },
        { value: "zzzz", type: :time_pattern }
      ]
      check_token_list(got, expected)
    end

    it "tokenizes both date and time patterns together" do
      got = described_class.tokenize("EEEE, d 'de' MMMM 'de' y, H:mm:ss (zzzz)")
      expected  = [
        { value: "EEEE", type: :date_pattern },
        { value: ", ", type: :plaintext },
        { value: "d", type: :date_pattern },
        { value: " 'de' ", type: :plaintext },
        { value: "MMMM", type: :date_pattern },
        { value: " 'de' ", type: :plaintext },
        { value: "y", type: :date_pattern },
        { value: ", ", type: :plaintext },
        { value: "H", type: :time_pattern },
        { value: ":", type: :plaintext },
        { value: "mm", type: :time_pattern },
        { value: ":", type: :plaintext },
        { value: "ss", type: :time_pattern },
        { value: " (", type: :plaintext },
        { value: "zzzz", type: :time_pattern },
        { value: ")", type: :plaintext }
      ]
      check_token_list(got, expected)
    end
  end
end
