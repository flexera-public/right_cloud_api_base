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

    # The Routine adds metadata to the result.
    #
    # @example:
    #  response = ec2.DescribeSecurityGroups #=> A list of SecurityGroups
    #  response.metadata #=>
    #    {:headers=>
    #      {"content-type"=>["text/xml;charset=UTF-8"],
    #       "transfer-encoding"=>["chunked"],
    #       "date"=>["Fri, 22 Feb 2013 00:02:43 GMT"],
    #       "server"=>["AmazonEC2"]},
    #     :code=>"200",
    #     :cache=>
    #      {:key=>"DescribeSecurityGroups",
    #       :record=>
    #        {:timestamp=>2013-02-22 00:02:44 UTC,
    #         :md5=>"0e3e12e1c18237d9f9510e90e7b8950e",
    #         :hits=>0}}}
    #
    class ResultWrapper < Routine

      class Result < BlankSlate
        attr_reader :metadata

        def initialize(response, metadata)
          @response = response
          @metadata = metadata
        end

        # Feed all the missing methods to the original object.
        def method_missing(method, *params, &block)
          @response.send(method, *params, &block)
        end
      end

      # Main entry point.
      #
      def process
        cache = data._at(:vars, :cache, :default => nil)
        metadata = {}
        metadata[:headers] = data[:response][:instance].headers
        metadata[:code]    = data[:response][:instance].code
        metadata[:cache]   = cache if cache
        #
        data[:result] = Result::new(data[:response][:parsed], metadata)
      end
    end
    
  end
end