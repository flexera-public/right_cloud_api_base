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

    # The routine analyzes HTTP responses and in the case of HTTP error it takes actions defined
    # through *error_pattern* definitions.
    #
    class ResponseAnalyzer < Routine

      class Error < CloudApi::Error
      end

      # Analyzes an HTTP response.
      # 
      # In the case of 4xx, 5xx HTTP errors the method parses the response body to get the
      # error message. Then it tries to find an error pattern that would match to the response.
      # If the pattern found it takes the action (:retry, :abort, :disconnect_and_abort or
      # :reconnect_and_retry) acordingly to the error patern. If the pattern not fount it just
      # fails with RightScale::CloudApi::CloudError.
      #
      # In the case of 2xx code the method does nothing.
      #
      # In the case of any other unexpected HTTP code it fails with RightScale::CloudApi::CloudError.
      #
      # @example
      #    error_pattern :abort_on_timeout,     :path     => /Action=(Run|Create)/
      #    error_pattern :retry,                :response => /InternalError|Internal Server Error|internal service error/i
      #    error_pattern :disconnect_and_abort, :code     => /5..|403|408/
      #    error_pattern :reconnect_and_retry,  :code     => /4../, :if => Proc.new{ |opts| rand(100) < 10 }
      #
      def process
        # Extract the current response and log it.
        response = data[:response][:instance]
        unless response.nil?
          cloud_api_logger.log("Response received: #{response.to_s}", :response_analyzer)
          cloud_api_logger.log("Response headers:  #{response.headers_info}", :response_analyzer)
          log_method = (response.is_error? || response.is_redirect?) ? :response_analyzer_body_error : :response_analyzer_body
          cloud_api_logger.log("Response body:     #{response.body_info}", log_method)
        end

        code = data[:response][:instance].code
        body = data[:response][:instance].body
        close_current_connection_proc = data[:callbacks][:close_current_connection]

        # Analyze the response code.
        case code
        when /^(5..|4..)/
          # Try to parse the received error message.
          error_message = if data[:options][:response_error_parser]
                            parser = data[:options][:response_error_parser]
                            with_timer("Error parsing with #{parser}") do
                              parser::parse(data[:response][:instance], data[:options])
                            end
                          else
                            "#{code}: #{body.to_s}"
                          end
          # Get the list of patterns.
          error_patterns = data[:options][:error_patterns] || []
          opts = { :request  => data[:request][:instance],
                   :response => data[:response][:instance],
                   :verb     => data[:request][:verb],
                   :params   => data[:request][:orig_params].dup }
          # Walk through all the patterns and find the first that matches.
          error_patterns.each do |pattern|
            if Utils::pattern_matches?(pattern, opts)
              cloud_api_logger.log("Response matches to error pattern: #{pattern.inspect}", :response_analyzer)
              # Take the requered action.
              case pattern[:action]
              when :disconnect_and_abort
                close_current_connection_proc && close_current_connection_proc.call('Error pattern match')
                fail(HttpError::new(code, error_message))
              when :reconnect_and_retry
                close_current_connection_proc && close_current_connection_proc.call('Error pattern match')
                fail(RetryAttempt::new)
              when :abort
                fail(HttpError::new(code, error_message))
              when :retry
                invoke_callback_method(data[:options][:before_retry_callback],
                                       :routine => self,
                                       :pattern => pattern,
                                       :opts    => opts)
                fail(RetryAttempt::new)
              end
            end
          end
          # The default behavior: this guy hits when there is no any matching pattern
          fail(HttpError::new(code, error_message))
        when /^3..$/
          # In the case of redirect: update a request URI and retry
          location = Array(data[:response][:instance].headers['location']).first
          # ----- AMAZON HACK BEGIN ----------------------------------------------------------
          # Amazon sometimes hide a location host into a response body.
          if location._blank? && body && body[/<Endpoint>(.*?)<\/Endpoint>/] && $1
            data[:connection][:uri].host = $1
            location = data[:connection][:uri].to_s
          end
          # ----- AMAZON HACK END ------------------------------------------------------------
          # Replace URI and retry if the location was successfully set
          unless location._blank?
            data[:connection][:uri] = ::URI.parse(location)
            old_request = data[:request].delete(:instance)
            data[:request].delete(:path)
            cloud_api_logger.log("Redirect detected: #{location.inspect}", :response_analyzer)
            invoke_callback_method(data[:options][:before_redirect_callback],
                                   :routine     => self,
                                   :old_request => old_request,
                                   :location    => location)
            raise(RetryAttempt::new)
          else
            fail(HttpError::new(code, "Cannot parse a redirect location"))
          end
        when /^2../
          # There is nothing to do on 2xx code
          return true
        else
          fail(Error::new("Unexpected response code: #{code.inspect}"))
        end
      end
    end

  end
end

