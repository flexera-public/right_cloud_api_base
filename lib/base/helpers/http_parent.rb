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

    # The parent class for HTTPRequest and HTTPResponse.
    #
    # @api public
    #
    # The class defines generic methods that are used by both Request and Response classes.
    #
    class HTTPParent

      # Returns Net::HTTPResponse object
      #
      # @return [Net::HTTPResponse]
      # @example
      #   # no example
      #
      attr_accessor :raw


      # Returns the response body
      #
      # @return [String,nil]
      # @example
      #   # no example
      #
      attr_accessor :body


      # Returns the response headers
      #
      # @return [Hash]
      # @example
      #   # no example
      #
      attr_reader   :headers


      # Returns all the headers for the current request/response instance
      #
      # @return [Hash] The set of headers.
      # @example
      #   # no example
      #
      def headers
        @headers.to_hash
      end


      # Retrieves the given header values
      #
      # @param [Hash] header The header name.
      # @return [Array] The Array of values for the header.
      #
      # @example
      #   # no example
      #
      def [](header)
        @headers[header]
      end


      # Returns true if the current object's body is an IO instance
      #
      # @return [Boolean] True if it is an IO and false otherwise.
      #
      # @example
      #   is_io? #=> false
      #
      def is_io?
        body.is_a?(IO) || body.is_a?(Net::ReadAdapter)
      end


      # Displays the current headers in a nice way
      #
      # @return [String]
      #
      # @example
      #   ec2.response.headers_info #=>
      #    'content-type: "text/xml;charset=UTF-8", server: "AmazonEC2", something: ["a", "b"]'
      #
      def headers_info
        @headers.to_s
      end
    end

  end
end
