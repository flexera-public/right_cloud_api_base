#--
# Copyright (c) 2013 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module RightScale
  module CloudApi

     # Cloud API Logger wraps the logger passed from the gateway or creates a new logger which logs to null by default
     # By default the logger logs at INFO level.
     #
     # Every log message should be associated with a log_filter(key). If no log filter(key) is
     # specified, then a message is logged and is not filterable.
     #
     # Any log_message with its key specified in log_filters is logged. If log_filters are not
     # specified then the log_messages which is not associated by the key is logged.
     #
     # If parent logger is set at DEBUG level then all the messages are logged by default.
     #
     # TODO: review the description.
     #
     class CloudApiLogger

      attr_reader :logger, :log_filters, :log_filter_patterns, :request_log_tag

       # Initializes a new logger.
       #
       # @param [Hash] options A set of options
       # @option options [String,IO] :logger  Creates a new Logger instance from teh given value.
       # @option options [NilClass]  :logger  Creates a new Logger instance that logs to STDOUT.
       # @option options [Array]     :log_filters  An array of topics to log (see {#help}
       #   for list of keys)
       # @option options [Array]     :log_filter_patterns  An array of Strings or RegExps of things
       #   that have to be filtered out from logs.
       #
       def initialize(options = {} , default_filters = [])
        @logger = options[:logger]
        if @logger.is_a?(String) || @logger.is_a?(IO)
          @logger                  = ::Logger::new(options[:logger])
          @logger.level            = ::Logger::INFO
          @logger.datetime_format  = "%Y%m%d %H%M%S"
          @logger.formatter        = proc { |severity, datetime, progname, msg| "#{severity[/^./]} #{datetime.strftime("%y%m%d %H%M%S")}: #{msg}\n" }
        elsif @logger.nil?
          @logger       = ::Logger::new(options.has_key?(:logger) ? '/dev/null' : STDOUT)
          @logger.level = ::Logger::INFO
        end
        @log_filters         = options[:log_filters]._blank? ? Array(default_filters) : Array(options[:log_filters])
        @log_filter_patterns = options[:log_filter_patterns]._blank? ? []             : Array(options[:log_filter_patterns])
      end

      # Logs the message at INFO level.
      #
      # @param [String] message  The given message
      # @param [Symbol] key  The filtering key.
      #
      def info(message, key = nil)
        log(message, key, :info)
      end

      # Logs the message at WARN level.
      #
      # @param [String] message  The given message
      # @param [Symbol] key  The filtering key.
      #
      def warn(message, key = nil)
        self.log(message, key, :warn)
      end

      # Logs the message at DEBUG level.
      #
      # @param [String] message  The given message
      # @param [Symbol] key  The filtering key.
      #
      def error(message, key = nil)
        self.log(message, key, :error)
      end

      # Returns a helper hash with all the supported topics.
      #
      # @return [Hash]  A set of log filter keys with explanations.
      #
      def self.help
        {
          :api_manager                  => "Enables ApiManager's logs",
          :wrapper                      => "Enables Wrapper's logs",
          :routine                      => "Enables Routine's logs",
          :cache_validator              => "Enables CacheValidator logs",
          :request_analyzer             => "Enables RequestAnalyzer logs",
          :request_generator            => "Enables RequestGenerator logs" ,
          :request_generator_body       => "Enables RequestGenerator body logging",
          :response_analyzer            => "Enables ResponseAnalizer logs",
          :response_analyzer_body       => "Enables ResponseAnalyzer body logging",
          :response_analyzer_body_error => "Enables ResponseAnalyzer body logging on error",
          :timer                        => "Enables timer logs",
          :retry_manager                => "Enables RetryManager logs",
          :right_http_connection_proxy  => "Enables RightHttpConnectionProxy logs",
          :connection_proxy             => "Enables ConnectionProxy logs",
          :all                          => "Enables all the possible log topics"
        }
      end

      # Logs the given message.
      #
      # @param [String] message The message to be logged.
      # @param [Symbol] key Filtering key.
      # @param [Symbol] method Logging method (:debug, :info, :etc).
      #
      def log(message, key = nil, method = :debug)
        if !key || log_filters.include?(key) || log_filters.include?(:all)
          logger.__send__(method, "#{request_log_tag}#{filter_message(message)}")
        end
      end

      # Generates a unique prefix and adds it to every logged line so that it is easy to identify
      # what log message is for what request.
      def add_unique_prefix
        @unique_prefix = RightScale::CloudApi::Utils::random(6)
      end

      def reset_unique_prefix
        @request_log_tag = nil
      end

      def request_log_tag
        @request_log_tag._blank? ? "" : "[#{@request_log_tag}] "
      end

      # Filters out all the things that match to log_filter_patterns in the given message
      #
      # @param [String] message The given message.
      #
      # @return [String] The original message that has sencitive things filtered out.
      #
      # TODO: Provide a way to adjust '[FILTERED]' message.
      #
      def filter_message(message)
        message = message.dup
        log_filter_patterns.each {|pattern| message.gsub!(pattern, '\1[FILTERED]\3')}
        message
      end
    end
  end
end