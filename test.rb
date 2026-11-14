require "twitter_cldr"
require "json"

test_cases = JSON.parse(File.read("vendor/cldr_v48.2/common/testData/datetime/datetime.json"))
failures = []

test_cases.each do |test_case|
  if test_case["calendar"] != "gregorian"
    STDOUT.write("S")
    next
  end

  time = DateTime.parse(test_case["input"]).localize(test_case["locale"])
  length = nil

  if test_case.include?("timeLength")
    length = test_case["timeLength"]
  elsif test_case.include?("dateLength")
    length = test_case["dateLength"]
  else
    STDOUT.write("S")
    next
  end

  mtd = :"to_#{length}_s"
  got = TwitterCldr::Normalization.normalize(time.send(mtd), using: :nfkc)
  expected = TwitterCldr::Normalization.normalize(test_case["expected"], using: :nfkc)

  if got == expected
    STDOUT.write(".")
  else
    STDOUT.write("F")
    failures << ["#{test_case["input"]} (#{test_case["locale"]})", expected, got]
  end
end

puts
puts

failures.each_with_index do |(source, expected, got), idx|
  puts "Failure #{idx + 1}:"
  puts "========================="
  puts "  Source: #{source}"
  puts
  puts "Expected: #{expected.inspect}"
  puts "     Got: #{got.inspect}"
  puts
end
