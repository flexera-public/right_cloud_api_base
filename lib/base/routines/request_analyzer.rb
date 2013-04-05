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

    # The routine provides *error_pattern* method that is used to define request and response patterns.
    #
    # The patterns allows one to control the request processing flow: you can enable retries for
    # certain API calls or can re-open a connection on HTTP failure.
    #
    # The supported actions are:
    #
    # Request option:
    # - :abort_on_timeout - If there was a low level timeout then it should not retry a request
    #   but should fail. Lets say one made a call to launch some instance and the remote cloud
    #   launched them but timed out to respond back. The default behavior for the gem is to make
    #   a retry if a timeout received but in this particular case it will launch the instances
    #   again. So the solution here is to make the system to fail after the first unsuccessfull
    #   request.
    #
    # Response options:
    # - :retry - Make a retry if the failed response matches to the pattern.
    # - :abort - Do not make a retry and fail if the response matches to the pattern (opposite to :retry).
    # - :disconnect_and_abort - Close a connection and fail.
    # - :reconnect_and_retry - Reestablish a connection and make a retry.
    #
    class RequestAnalyzer < Routine

      class Error < CloudApi::Error
      end

      REQUEST_ACTIONS  = [ :abort_on_timeout ]
      REQUEST_KEYS     = [ :verb, :verb!, :path, :path!, :request, :request!, :if ]

      RESPONSE_ACTIONS = [ :disconnect_and_abort, :abort, :reconnect_and_retry, :retry ]
      RESPONSE_KEYS    = [ :verb, :verb!, :path, :path!, :request, :request!, :code, :code!, :response, :response!, :if ]

      ALL_ACTIONS      = REQUEST_ACTIONS + RESPONSE_ACTIONS
      
      module ClassMethods

        def self.extended(base)
          unless base.respond_to?(:options) && base.options.is_a?(Hash)
            fail Error::new("RequestAnalyzer routine assumes class being extended responds to :options and returns a hash")
          end
        end

        # Adds a new error pattern.
        # Patterns are analyzed in order of their definition. If one pattern hits the rest are not analyzed.
        # 
        # @param [Symbol] action The requested action.
        # @param [Hash]   error_pattern The requested pattern (see {file:lib/base/helper/utils.rb self.pattern_matches?}).
        # 
        # @xample:
        #    error_pattern :abort_on_timeout,     :path     => /Action=(Run|Create)/
        #    error_pattern :retry,                :response => /InternalError|Internal Server Error|internal service error/i
        #    error_pattern :disconnect_and_abort, :code     => /5..|403|408/
        #    error_pattern :disconnect_and_abort, :code     => /4../, :if => Proc.new{ |opts| rand(100) < 10 }
        #
        # @raise [RightScale::CloudApi::RequestAnalyzer::Error] If error_pattern  is not a Hash instance.
        # @raise [RightScale::CloudApi::RequestAnalyzer::Error] If action is not supported.
        # @raise [RightScale::CloudApi::RequestAnalyzer::Error] If pattern keys are weird.
        #
        def error_pattern(action, error_pattern)
          action = action.to_sym
          fail Error::new("Patterns are not set for action #{action.inspect}") if !error_pattern.is_a?(Hash) || error_pattern._blank?
          fail Error::new("Unsupported action #{action.inspect} for error pattern #{error_pattern.inspect}") unless ALL_ACTIONS.include?(action)
          unsupported_keys = REQUEST_ACTIONS.include?(action) ? error_pattern.keys - REQUEST_KEYS : error_pattern.keys - RESPONSE_KEYS
          fail Error::new("Unsupported keys #{unsupported_keys.inspect} for #{action.inspect} in error pattern #{error_pattern.inspect}") unless unsupported_keys._blank?
          (options[:error_patterns] ||= []) << error_pattern.merge(:action => action)
        end
      end

      # The main entry point.
      #
      def process
        # Get a list of accessible error patterns
        error_patterns = data[:options][:error_patterns] || []
        opts = { :request  => data[:request][:instance],
                 :response => nil,
                 :verb     => data[:request][:verb],
                 :params   => data[:request][:orig_params].dup}
        # Walk through all the error patterns and find the first that matches.
        # RequestAnalyser accepts only REQUEST_ACTIONS (actually "abort_on_timeout" only)
        request_error_patterns = error_patterns.select{|e| REQUEST_ACTIONS.include?(e[:action])}
        request_error_patterns.each do |pattern|
          # If we see any pattern that matches our current state
          if Utils::pattern_matches?(pattern, opts)
            # then set a flag to disable retries
            data[:options][:abort_on_timeout] = true
            cloud_api_logger.log("Request matches to error pattern: #{pattern.inspect}" , :request_analyzer)
            break
          end
        end
      end
    end

  end
end


