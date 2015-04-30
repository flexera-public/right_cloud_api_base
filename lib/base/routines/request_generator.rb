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

    # The routine generates a new HTTP request.
    #
    class RequestGenerator < Routine

      # Generates an HTTP request instance.
      #
      # The request instance must be compatible to what ConnectionProxy is being used expects.
      #
      def process
        request = HTTPRequest::new( data[:request][:verb],
                                    data[:request][:path],
                                    data[:request][:body],
                                    data[:request][:headers] )
        cloud_api_logger.log("data: #{data.inspect}" ,         :request_generator)
        cloud_api_logger.log("Request generated: #{request.to_s}" ,         :request_generator)
        cloud_api_logger.log("Request headers:   #{request.headers_info}" , :request_generator)
        cloud_api_logger.log("Request body:      #{request.body_info}\n",   :request_generator_body) unless (request.body.to_s.size == 0)
        data[:request][:instance] = request
      end
    end

  end
end
