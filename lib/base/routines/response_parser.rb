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

    # The routine parses the current response.
    # 
    # The supportes content-types are: xml and json.
    # In the case of any other content-type it does nothing.
    #
    class ResponseParser < Routine

      # Main entry point.
      #
      def process
        # There is no way to parse an IO response
        return nil if data[:response][:instance].is_io?

        xml_parser   = Utils::get_xml_parser_class(data[:options][:xml_parser])
        content_type = (data[:response][:instance].headers || {})["content-type"].to_s
        body         = data[:response][:instance].body.to_s
        # Find the appropriate parser.
        parser = if body._blank?
                   Parser::Plain
                 else
                   case content_type
                   when /xml/              then xml_parser
                   when /json|javascript/  then Parser::Json
                   else
                     if data[:response][:instance].body.to_s[/\A<\?xml /]
                       # Sometimes Amazon does not set a proper header
                       xml_parser
                     else
                       Parser::Plain
                     end
                   end
                 end
        # Parse the response
        with_timer("Response parsing with #{parser}") do
          data[:response][:parsed] = parser::parse(body)
        end
        data[:result] = data[:response][:parsed]
      end
    end
    
  end
end