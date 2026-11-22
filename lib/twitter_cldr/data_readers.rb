# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

module TwitterCldr
  module DataReaders
    autoload :DataReader,         "twitter_cldr/data_readers/data_reader"
    autoload :NumberDataReader,   "twitter_cldr/data_readers/number_data_reader"
    autoload :TimespanDataReader, "twitter_cldr/data_readers/timespan_data_reader"
  end
end
