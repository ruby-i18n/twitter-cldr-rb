require "twitter_cldr"

def match_skeleton(skeleton, options, allow_different_fields: false)
  # Filter out falsy values and sort for stability; when `interval_formats` is passed in, there may be a None key.
  options = options.reject(&:empty?).sort

  if skeleton.include?('z') && options.none? { |opt| opt.include?('z') }
    skeleton = skeleton.gsub('z', 'v')
  end

  if skeleton.include?('k') && options.none? { |opt| opt.include?('k') }
    skeleton = skeleton.gsub('k', 'H')
  end

  if skeleton.include?('K') && options.none? { |opt| opt.include?('K') }
    skeleton = skeleton.gsub('K', 'h')
  end

  if skeleton.include?('a') && options.none? { |opt| opt.include?('a') }
    skeleton = skeleton.gsub('a', '')
  end

  if skeleton.include?('b') && options.none? { |opt| opt.include?('b') }
    skeleton = skeleton.gsub('b', '')
  end

  input_field_width_map = TwitterCldr::Tokenizers::DateTimeTokenizer.tokenize(skeleton).each_with_object({}) do |token, memo|
    next if token.type != :date_pattern && token.type != :time_pattern
    memo[token.value[0]] = token.value.size
  end

  best_skeleton = nil
  best_distance = nil

  options.each do |option|
    opt_field_width_map = TwitterCldr::Tokenizers::DateTimeTokenizer.tokenize(option).each_with_object({}) do |token, memo|
      next if token.type != :date_pattern && token.type != :time_pattern
      memo[token.value[0]] = token.value.size
    end

    distance = 0

    TwitterCldr::Formatters::DateTimeFormatter::PATTERN_MAP.each_key do |field|
      input_width = input_field_width_map.fetch(field, 0)
      opt_width = opt_field_width_map.fetch(field, 0)

      next if input_width == opt_width

      if opt_width == 0 || input_width == 0
        unless allow_different_fields  # This one is not okay
          option = nil
          break
        end

        # Magic weight constant for "entirely different fields"
        distance += 0x1000
      elsif field == 'M' && ((input_width > 2 && opt_width <= 2) || (input_width <= 2 && opt_width > 2))
        # Magic weight constant for "text turns into a number"
        distance += 0x100
      else
        distance += (input_width - opt_width).abs
      end
    end

    # We lost the option along the way (probably due to "allow_different_fields")
    next unless option

    if !best_skeleton || distance < best_distance
      best_skeleton = option
      best_distance = distance
    end

    break if distance == 0  # Found a perfect match!
  end

  best_skeleton
end

additional_formats = YAML.load(File.read("resources/locales/en/calendars.yml")).dig(:en, :calendars, :gregorian, :additional_formats)
puts match_skeleton("yyMdEEE", additional_formats.keys.map(&:to_s)).inspect

adfs = TwitterCldr::DataReaders::AdditionalDateFormatSelector.new(additional_formats)
puts adfs.find_closest("yyMdEEE").inspect
