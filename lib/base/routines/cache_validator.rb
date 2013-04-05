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

    # The routine processes cache validations (when caching is enabled).
    #
    # It takes a response from a cloud and tries to find a pre-defined caching pattern that would
    # fit to this response and its request. If there is a pattern it extracts a previous response
    # from the cache and compares it to the current one.
    #
    # If both the responses match it raises RightScale::CloudApi::CacheHit exception.
    #
    # The main point of the caching - it is performed before parsing a response. So if we get a 10M
    # XML from Amazon it will take seconds to parse it but if the response did not change there is
    # need to parse it.
    #
    # @example
    #   ec2 = RightScale::CloudApi::AWS::EC2.new(key, secret_key, :cache => true)
    #   ec2.DescribeInstances #=> a list of instances
    #   ec2.DescribeInstances(:options => {:cache => false}) #=> the same list of instances
    #   ec2.DescribeInstances #=> exception if the response did not change
    #
    # The caching setting is per cloud specific ApiManager. For some of them it is on by default so
    # you need to look at the ApiManager definition.
    #
    class CacheValidator < Routine

      class Error < CloudApi::Error
      end

      # Logs a message.
      #
      # @param [String] message Some text.
      #
      def log(message)
        cloud_api_logger.log( "#{message}", :cache_validator)
      end

      module ClassMethods
        CACHE_PATTERN_KEYS = [ :verb, :verb!, :path, :path!, :request, :request!, :code, :code!, :response, :response!, :key, :if, :sign ]

        def self.extended(base)
          unless base.respond_to?(:options) && base.options.is_a?(Hash)
            raise Error::new("CacheValidator routine assumes class being extended responds to :options and returns a hash") 
          end
        end

        # Adds new cache patters.
        # Patterns are analyzed in order of their definnition. If one pattern hits
        # the rest are not analyzed.
        # 
        # @param [Hash] cache_pattern A hash of pattern keys.
        # @option cache_pattern [Proc] :key A method that calculates a kache key name.
        # @option cache_pattern [Proc] :sign A method that modifies the response before calculating md5.
        #
        # @see file:lib/base/helper/utils.rb self.pattern_matches? for the other options.
        # 
        # @example:
        #  cache_pattern :verb  => /get|post/,
        #                :path  => /Action=Describe/,
        #                :if    => Proc::new{ |o| (o[:params].keys - %w{Action Version AWSAccessKeyId})._blank? },
        #                :key   => Proc::new{ |o| o[:params]['Action'] },
        #                :sign  => Proc::new{ |o| o[:response].body.to_s.sub(%r{<requestId>.+?</requestId>}i,'') }
        #
        def cache_pattern(cache_pattern)
          fail Error::new("Pattern should be a Hash and should not be blank") if !cache_pattern.is_a?(Hash) || cache_pattern._blank?
          fail Error::new("Key field not found in cache pattern definition #{cache_pattern.inspect}") unless cache_pattern.keys.include?(:key)
          unsupported_keys = cache_pattern.keys - CACHE_PATTERN_KEYS
          fail Error::new("Unsupported keys #{unsupported_keys.inspect} in cache pattern definition #{cache_pattern.inspect}") unless unsupported_keys._blank?
          (options[:cache_patterns] ||= []) << cache_pattern
        end
      end

      # The main entry point.
      #
      def process
        # Do nothing if caching is off
        return nil unless data[:options][:cache]
        # There is nothing to cache if we stream things
        return nil if data[:response][:instance].is_io?

        cache_patterns = data[:options][:cache_patterns] || []
        opts = { :relative_path => data[:request][:relative_path],
                 :request       => data[:request][:instance],
                 :response      => data[:response][:instance],
                 :verb          => data[:request][:verb],
                 :params        => data[:request][:orig_params].dup }

        # Walk through all the cache patterns and find the first that matches
        cache_patterns.each do |pattern|
          # Try on the next pattern unless the current one matches.
          next unless Utils::pattern_matches?(pattern, opts)
          # Process the matching pattern.
          log("Request matches to cache pattern: #{pattern.inspect}")
          # Build a cache key and get a text to be signed
          cache_key, text_to_sign = build_cache_key(pattern, opts)
          cache_record = {
            :timestamp => Time::now.utc,
            :md5       => Digest::MD5::hexdigest(text_to_sign).to_s,
            :hits      => 0
          }
          log("Processing cache record: #{cache_key} => #{cache_record.inspect}")
          # Save current cache key for later use (by other Routines)
          data[:vars][:cache] ||= {}
          data[:vars][:cache][:key]    = cache_key
          data[:vars][:cache][:record] = cache_record
          # Get the cache storage
          storage = (data[:vars][:system][:storage][:cache] ||= {} )
          unless storage[cache_key]
            # Create a new record unless exists.
            storage[cache_key] = cache_record
            log("New cache record created")
          else
            # If the record is already there but the response changed the replace the old record.
            unless storage[cache_key][:md5] == cache_record[:md5]
              storage[cache_key] = cache_record
              log("Missed. Record is replaced")
            else
              # Raise if cache hits.
              storage[cache_key][:hits] += 1
              message = "Cache hit: #{cache_key.inspect} has not changed since " +
                        "#{storage[cache_key][:timestamp].strftime('%Y-%m-%d %H:%M:%S')}, "+
                        "hits: #{storage[cache_key][:hits]}."
              log(message)
              fail CacheHit::new("CacheValidator: #{message}")
            end
          end
          break
        end
        true
      end

    private

      # Builds the cached record key and body.
      #
      # @param [Hash] pattern The pattern that matched to the current response.
      # @option options [Hash] opts A set of options that will be passed to :key and :sign procs.
      #
      # @return [Array] An array: [key, body]
      #
      # @raise [RightScale::CloudApi::CacheValidator::Error] Unless :key proc id set.
      # @raise [RightScale::CloudApi::CacheValidator::Error] Unless :sign proc returns a valid body.
      #
      # @example
      #  build_cache_key(pattern) #=>
      #    ["DescribeVolumes", "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DescribeVolumesResponse ... </DescribeVolumesResponse>"]
      #
      def build_cache_key(pattern, opts)
        key = pattern[:key].is_a?(Proc) ? pattern[:key].call(opts) : pattern[:key]
        fail Error::new("Cannot build cache key using pattern #{pattern.inspect}") unless key

        body_to_sign = opts[:response].body.to_s if opts[:response].body
        body_to_sign = pattern[:sign].call(opts) if pattern[:sign]
        fail Error::new("Could not create body to sign using pattern #{pattern.inspect}") unless body_to_sign

        [key, body_to_sign]
      end

    end
  end
end
