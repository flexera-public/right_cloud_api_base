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

    # This routine generifies all HTTP requests so that the main code does not need to worry about
    # the underlaying libraries (right_http_connection or persistent_connection).
    #
    class ConnectionProxy < Routine
      class Error < CloudApi::Error
      end

      # Main entry point.
      #
      # Performs an HTTP request.
      #
      def process
        unless @connection_proxy
          # Try to use a user defined connection proxy. The options are:
          #  - RightScale::CloudApi::ConnectionProxy::RightHttpConnectionProxy,
          #  - RightScale::CloudApi::ConnectionProxy::NetHttpPersistentProxy
          connection_proxy_class = data[:options][:connection_proxy]
          unless connection_proxy_class
            # If it is not defined then load right_http_connection gem and use it.
            # connection_proxy_class = ConnectionProxy::RightHttpConnectionProxy
            connection_proxy_class = RightScale::CloudApi::ConnectionProxy::NetHttpPersistentProxy
          end
          @connection_proxy = connection_proxy_class.new
        end

        # Register a call back to close current connection
        data[:callbacks][:close_current_connection] = Proc::new do |reason|
          @connection_proxy.close_connection(nil, reason)
          cloud_api_logger.log("Current connection closed: #{reason}", :connection_proxy)
        end

        # Make a request.
        with_timer('HTTP request', :connection_proxy) do
          @connection_proxy.request(data)
        end
      end

    end
  end
end