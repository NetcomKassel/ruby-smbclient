require 'time'

module SMBClient
  module Helpers
    class LsItem
      attr_accessor :name, :type, :size, :change_time

      def initialize(name, type, size, change_time)
        @name = name
        @type = type
        @size = size.to_i
        @change_time = Time.parse change_time
      end

      def directory?
        @type == 'D'
      end

      def file?
        @type == 'A'
      end

      def self.parse_line(line)
        match_data = /(?<name>[\.|\w]+)\s+(?<type>.)\s+(?<size>\d+)\s+(?<change_time>.+)/.match line
        return nil unless match_data
        LsItem.new match_data[:name], match_data[:type],
                   match_data[:size], match_data[:change_time]
      end
    end
  end
end
