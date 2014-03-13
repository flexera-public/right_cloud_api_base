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

    # A Wrapper around standard Net::HTTPRequest class.
    #
    # @api public
    #
    # The class supports some handy methods for managing the verb, the body, the path and the headers.
    # And everythig else can be accessed through *raw* attribute that points to the original
    # Net::HTTPRequest instance.
    #
    class HTTPRequest < HTTPParent


      # Request HTTP verb
      #
      # @return [String]
      # @example
      #   response.verb #=> 'get'
      #
      attr_accessor :verb


      # Request path
      #
      # @return [String]
      # @example
      #   response.path #=> 'xxx/yyy/zzz'
      #
      attr_accessor :path


      # Request HTTP params
      #
      # @return [Hash]
      # @example
      #   response.params #=> { 'a' => 'b', 'c' => 'd' }
      #
      attr_accessor :params


      # Max byte to log
      BODY_BYTES_TO_LOG = 6000


      # Constructor
      #
      # @param [String,Symbol] verb The current verb ('get', 'post', 'put', etc).
      # @param [String,IO,Nil] body The request body.
      # @param [String] path The URL path.
      # @param [Hash] headers The request headers.
      # @param [Net::HTTPRequest] raw The original request (optional).
      #
      # @return [Rightscale::CloudApi::HTTPRequest] A new instance.
      #
      # @example
      #   new('get', 'xxx/yyy/zzz', nil, {})
      #
      def initialize(verb, path, body, headers, raw=nil)
        # Create a request
        @verb     = verb.to_s.downcase
        @path     = path
        @raws     = raw
        @headers  = HTTPHeaders::new(headers)
        self.body = body
      end


      # Sets a new headers value(s)
      #
      # @param [String] header The header name.
      # @param [String, Array] value The value for the header.
      # @return [void]
      # @example
      #   # no example
      #
      def []=(header, value)
        @headers[header] = value
      end


      # Sets the body and the 'content-length' header
      #
      # If the body is blank it sets the header to 0.
      # If the body is a String it sets the header to the string size.
      # If the body is an IO object it tries to open it in *binmode* mode and sets the header to
      # the filesize (if the header is not set or points outside of the range of (0..filesize-1)).
      #
      # @param [Object] new_body
      # @return [void]
      # @example
      #   # no example
      #
      def body=(new_body)
        # Set a request body
        if new_body._blank?
          @body = nil
          self['content-length'] = 0
        else
          if new_body.is_a?(IO)
            @body = file = new_body
            # Make sure the file is openned in binmode
            file.binmode if file.respond_to?(:binmode)
            # Fix 'content-length': it must not be bigger than a piece of a File left to be read or a String body size.
            # Otherwise the connection may behave like crazy causing 4xx or 5xx responses
            # KD: Make sure this code is used with the patched RightHttpConnection gem (see net_fix.rb)
            file_size     = file.respond_to?(:lstat) ? file.lstat.size : file.size
            bytes_to_read = [ file_size - file.pos, self['content-length'].first ].compact.map{|v| v.to_i }.sort.first # remove nils then make values Integers
            if self['content-length'].first._blank? || self['content-length'].first.to_i > bytes_to_read
              self['content-length'] = bytes_to_read
            end
          else
            @body = new_body
            self['content-length'] = body.size if self['content-length'].first.to_i > body.size
          end
        end
      end


      # Displays the request as a String with the verb and the path
      #
      # @return [String] The request verb and path info.
      # @example
      #   ec2.request.to_s #=>
      #    "GET /?AWSAccessKeyId=000..000A&Action=DescribeSecurityGroups&SignatureMethod=HmacSHA256&
      #      SignatureVersion=2&Timestamp=2013-02-22T23%3A54%3A30.000Z&Version=2012-10-15&
      #      Signature=Gd...N4yQStO5aKXfYnrM4%3D"
      #
      def to_s
        "#{verb.upcase} #{path}"
      end


      # Displays the body information
      #
      # @return [String] The body info.
      # @example
      #   request.body_info #=> "something"
      #
      def body_info
        if is_io?
          "#{body.class.name}, size: #{body.respond_to?(:lstat) ? body.lstat.size : body.size}, pos: #{body.pos}"
        else
          "size: #{body.to_s.size}, first #{BODY_BYTES_TO_LOG} bytes:\n#{body.to_s[0...BODY_BYTES_TO_LOG]}"
        end
      end
    end

  end
end