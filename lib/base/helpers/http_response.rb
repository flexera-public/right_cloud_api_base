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

    # A Wrapper around standard Net::HTTPRsponse class
    #
    # @api public
    #
    # The class supports some handy methods for managing the code, the body and the headers.
    # And everythig else can be accessed through *raw* attribute that points to the original
    # Net::HTTPResponse instance.
    #
    class HTTPResponse < HTTPParent

      # The response code
      #
      # @return [String]
      # @example
      #   response.code #=> '404'
      #
      attr_reader :code

      # Body bytes to log
      BODY_BYTES_TO_LOG = 2000

      # Body bytes to log in case of error
      BODY_BYTES_TO_LOG_ERROR = 6000


      # Constructor
      #
      # @param [String] code The http response code.
      # @param [String,IO,Nil] body The response body.
      # @param [Hash] headers The response headers.
      # @param [Net::HTTPRequest] raw The original response (optional).
      #
      # @return [Rightscale::CloudApi::HTTPResponse] A new response instance.
      #
      # @example
      #   new('200', 'body', {}, object)
      #
      def initialize(code, body, headers, raw)
        @code    = code.to_s
        @body    = body
        @raw     = raw
        @headers = HTTPHeaders::new(headers)
      end


      # Returns true if the response code is in the range of 4xx or 5xx
      #
      # @return [Boolean]
      # @example
      #   response.is_error? #=> false
      #
      def is_error?
        !!(code.is_a?(String) && code.match(/^(5..|4..)/))
      end


      # Returns true if the response code is in the range of 3xx
      #
      # @return [Boolean]
      # @example
      #   response.is_redirect? #=> false
      #
      def is_redirect?
        !!(code.is_a?(String) && code.match(/^3..$/))
      end


      # Returns the response code and code name
      #
      # @return [String]
      # @example
      #   ec2.response.to_s #=> '200 OK'
      #
      def to_s
        result = code.dup
        result << " #{raw.class.name[/Net::HTTP(.*)/] && $1}" if raw.is_a?(Net::HTTPResponse)
        result
      end


      # Displays the body information
      #
      # @return [String] The body info.
      # @example
      #   ec2.response.body_info #=> 'response boby'
      #
      def body_info
        if    is_io?    then "#{body.class.name}"
        elsif is_error? then "size: #{body.to_s.size}, first #{BODY_BYTES_TO_LOG_ERROR} bytes:\n#{body.to_s[0...BODY_BYTES_TO_LOG_ERROR]}"
        else                 "size: #{body.to_s.size}, first #{BODY_BYTES_TO_LOG} bytes:\n#{body.to_s[0...BODY_BYTES_TO_LOG]}"
        end
      end
    end

  end
end