# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module Formatters
    module Rbnf

      class InvalidRbnfTokenError < StandardError; end

      class RuleFormatter
        class << self

          attr_accessor :keep_soft_hyphens

          def format(number, rule_set, rule_group, locale)
            rule = rule_set.rule_for(number)
            formatter = formatter_for(rule, rule_set, rule_group, locale)
            result = formatter.format(number, rule)
            keep_soft_hyphens ? result : remove_soft_hyphens(result)
          end

          def formatter_for(rule, rule_set, rule_group, locale)
            const = case rule.base_value
              when Rule::MASTER
                MasterRuleFormatter
              when Rule::IMPROPER_FRACTION
                ImproperFractionRuleFormatter
              when Rule::PROPER_FRACTION
                ProperFractionRuleFormatter
              when Rule::NEGATIVE
                NegativeRuleFormatter
              else
                NormalRuleFormatter
            end

            const.new(rule_set, rule_group, locale)
          end

          private

          def remove_soft_hyphens(result)
            result.gsub([173].pack("U*"), "")
          end

        end

        self.keep_soft_hyphens = true  # default value
      end

      class NormalRuleFormatter
        attr_reader :rule_set, :rule_group, :omit, :is_fractional, :locale

        def initialize(rule_set, rule_group, locale)
          @rule_set = rule_set
          @rule_group = rule_group
          @is_fractional = false
          @locale = locale
        end

        def format(number, rule, tokens = rule.tokens)
          tokens.map do |token|
            send(token.type, number, rule, token)
          end.join
        end

        def right_arrow(number, rule, token)
          prev_rule = rule_set.previous_rule_for(rule) if token.length == 3
          remainder = (number.abs % rule.divisor) * (number < 0 ? -1 : 1)
          generate_replacement(remainder, prev_rule, token)
        end

        def left_arrow(number, rule, token)
          quotient = (number.abs / rule.divisor) * (number < 0 ? -1 : 1)
          generate_replacement(quotient, rule, token)
        end

        def equals(number, rule, token)
          generate_replacement(number, rule, token)
        end

        def generate_replacement(number, rule, token)
          if rule_set_name = token.rule_set_reference
            RuleFormatter.format(
              number,
              rule_group.rule_set_for(rule_set_name),
              rule_group,
              locale
            )
          elsif decimal_format = token.decimal_format
            sign = number < 0 ? :negative : :positive
            @data_reader ||= TwitterCldr::DataReaders::NumberDataReader.new(locale)
            decimal_format = @data_reader.pattern_for_sign(decimal_format, sign)
            @decimal_tokenizer ||= TwitterCldr::Tokenizers::NumberTokenizer.new(@data_reader)
            decimal_tokens = @decimal_tokenizer.tokenize(decimal_format)
            @decimal_formatter ||= TwitterCldr::Formatters::NumberFormatter.new(@data_reader)
            @decimal_formatter.format(
              decimal_tokens, number, type: :decimal
            )
          else
            RuleFormatter.format(number, rule_set, rule_group, locale)
          end
        end

        def alternation(number, rule, token)
          if rule.even_multiple_of?(number)
            if !token.right.empty?
              return format(number, rule, token.right)
            end
          else
            if !token.left.empty?
              return format(number, rule, token.left)
            end
          end

          ""
        end

        def plaintext(number, rule, token)
          token.value
        end

        # if a decimal token occurs here, it's actually plaintext
        def decimal(number, rule, token)
          token.value
        end

        def semicolon(number, rule, token)
          ""
        end

        def plural(number, rule, token)
          token.render(number / rule.divisor)
        end

        protected

        def fractional_part(number)
          ".#{number.to_s.split(".")[1] || 0}".to_f
        end

        def integral_part(number)
          number.to_s.split(".").first.to_i
        end

        def transliterate?
          !SKIP_DECIMAL_TRANSLITERATION.include?(locale)
        end
      end

      class NegativeRuleFormatter < NormalRuleFormatter
        def right_arrow(number, rule, token)
          generate_replacement(number.abs, rule, token)
        end

        def left_arrow(number, rule, token)
          raise invalid_token_error(token)
        end

        def alternation(number, rule, token)
          raise InvalidRbnfTokenError, "Alternations are not allowed in negative number rules."
        end

        private

        def invalid_token_error(token)
          InvalidRbnfTokenError.new("'#{token.value}' not allowed in negative number rules.")
        end
      end

      class MasterRuleFormatter < NormalRuleFormatter
        def right_arrow(number, rule, token)
          # Format by digits. This is not explained in the main doc. See:
          # http://grepcode.com/file/repo1.maven.org/maven2/com.ibm.icu/icu4j/51.2/com/ibm/icu/text/NFSubstitution.java#FractionalPartSubstitution.%3Cinit%3E%28int%2Ccom.ibm.icu.text.NFRuleSet%2Ccom.ibm.icu.text.RuleBasedNumberFormat%2Cjava.lang.String%29

          # doesn't seem to matter if the descriptor is two or three arrows, although three seems to indicate
          # we should or should not be inserting spaces somewhere (not sure where)
          is_fractional = true
          number.to_s.split(".")[1].each_char.map do |digit|
            RuleFormatter.format(digit.to_i, rule_set, rule_group, locale)
          end.join(" ")
        end

        def left_arrow(number, rule, token)
          if is_fractional
            # is this necessary?
            RuleFormatter.format(
              (number * fractional_rule(number).base_value).to_i,
              rule_set, rule_group, locale
            )
          else
            generate_replacement(integral_part(number), rule, token)
          end
        end

        def alternation(number, rule, token)
          if is_fractional
            fractional_alternation(number, rule, token)
          else
            default_alternation(number, rule, token)
          end
        end

        protected

        def fractional_alternation(number, rule, token)
          if (number * fractional_rule(number).base_value) == 1
            if !token.right.empty?
              format(number, rule, token.right)
            end
          else
            if !token.left.empty?
              format(number, rule, token.left)
            end
          end

          ""
        end

        def default_alternation(number, rule, token)
          if number.is_a?(Integer)
            if !token.right.empty?
              format(number, rule, token.right)
            end
          else
            if !token.left.empty?
              format(number, rule, token.left)
            end
          end

          ""
        end

        def fractional_rule(number)
          @fractional_rule ||= rule_set.rule_for(number, true)
        end
      end

      class ProperFractionRuleFormatter < MasterRuleFormatter
        def open_bracket(number, rule, token)
          raise invalid_token_error(token)
        end

        def close_bracket(number, rule, token)
          raise invalid_token_error(token)
        end

        def alternation(number, rule, token)
          raise InvalidRbnfTokenError, "Alternations are not allowed in proper fraction rules."
        end

        private

        def invalid_token_error(token)
          InvalidRbnfTokenError.new("'#{token.value}' not allowed in proper fraction rules.")
        end
      end

      class ImproperFractionRuleFormatter < MasterRuleFormatter
        def alternation(number, rule, token)
          if number > 0 && number < 1
            if !token.right.empty?
              return format(number, rule, token.right)
            end
          else
            if !token.left.empty?
              return format(number, rule, token.left)
            end
          end

          ""
        end
      end

    end
  end
end
