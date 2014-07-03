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
    class ConnectionProxy
      
      class NetHttpPersistentProxy
        class Error < CloudApi::Error
        end


        # Known timeout errors
        TIMEOUT_ERRORS = /Timeout|ETIMEDOUT/

        # Other re-triable errors
        OTHER_ERRORS   = /SocketError|EOFError/


        def log(message)
          @data[:options][:cloud_api_logger].log(message, :connection_proxy, :warn)
        end
        
        # Performs an HTTP request.
        #
        # @param [Hash] data The API request +data+ storage.
        #   See {RightScale::CloudApi::ApiManager.initialize_api_request_options} code for its explanation.
        #
        # P.S. Options not supported by Net::HTTP::Persistent:
        # :connection_retry_count, :connection_retry_delay, :cloud_api_logger
        #
        def request(data)
          require "net/http/persistent"

          @data = data
          @data[:response] = {}
          uri = @data[:connection][:uri]
          
          # Create a connection
          connection = Net::HTTP::Persistent.new('right_cloud_api_gem')

          # Create a fake HTTP request
          fake = @data[:request][:instance]
          http_request = "Net::HTTP::#{fake.verb._camelize}"._constantize::new(fake.path)
          if fake.is_io?
            http_request.body_stream = fake.body
          else
            http_request.body = fake.body
          end
          fake.headers.each{|header, value| http_request[header] = value }
          fake.raw = http_request

          # Register a callback to close current connection
          @data[:callbacks][:close_current_connection] = Proc::new do |reason|
            connection.shutdown
            log "Current connection closed: #{reason}"
          end
          
          # Set all required options
          # P.S. :connection_retry_count, :http_connection_retry_delay are not supported by this proxy
          #
          http_request['user-agent'] ||= @data[:options][:connection_user_agent] if @data[:options].has_key?(:connection_user_agent)
          connection.ca_file      = @data[:options][:connection_ca_file]         if @data[:options].has_key?(:connection_ca_file)
          connection.read_timeout = @data[:options][:connection_read_timeout]    if @data[:options].has_key?(:connection_read_timeout)
          connection.open_timeout = @data[:options][:connection_open_timeout]    if @data[:options].has_key?(:connection_open_timeout)
          connection.cert         = OpenSSL::X509::Certificate.new(@data[:credentials][:cert]) if @data[:credentials].has_key?(:cert)
          connection.key          = OpenSSL::PKey::RSA.new(@data[:credentials][:key])          if @data[:credentials].has_key?(:key)

          # Make a request
          begin
            make_request_with_retries(connection, uri, http_request)
          rescue => e
            fail(ConnectionError, e.message)
          ensure #ensuring we shutdown the connection, we were having some connection re-use issues and need to investigate that further
            connection.shutdown
          end
        end


        # Makes request with low level retries.
        #
        # Net::HTTP::Persistent does not fully support retries logic that we used to have.
        # To deal with this we disable Net::HTTP::Persistent's retries and handle them in our code.
        #
        # @param [Net::HTTP::Persistent] connection
        # @param [URI] uri
        # @param [Net::HTTPRequest] http_request
        #
        # @return [void]
        #
        def make_request_with_retries(connection, uri, http_request)
          disable_net_http_persistent_retries(connection)
          # Initialize retry vars:
          connection_retry_count = @data[:options][:connection_retry_count] || 3
          connection_retry_delay = @data[:options][:connection_retry_delay] || 0.5
          retries_performed      = 0
          # If block is given - pass there all the chunks of a response and then stop
          # (don't do any parsing, analysis, etc)
          block = @data[:vars][:system][:block]
          begin
            if block
              # Response.body is a Net::ReadAdapter instance - it can't be read as a string.
              # WEB: On its own, Net::HTTP causes response.body to be a Net::ReadAdapter when you make a request with a block
              # that calls read_body on the response.
              connection.request(uri, http_request) do |response|
                # If we are at the point when we have started reading from the remote end
                # then there is no low level retry is allowed. Otherwise we would need to reset the
                # IO pointer, etc.
                connection_retry_count = 0
                # Set IO response
                set_http_response(response)
                response.read_body(&block)
              end
            else
              # Set text response
              response = connection.request(uri, http_request)
              set_http_response(response)
            end
            nil
          rescue => e
            # Fail if it is an unknown error
            fail(e) if !(e.message[TIMEOUT_ERRORS] || e.message[OTHER_ERRORS])
            # Fail if it is a Timeout and timeouts are banned
            fail(e) if e.message[TIMEOUT_ERRORS] && !!@data[:options][:abort_on_timeout]
            # Fail if there are no retries left...
            fail(e) if (connection_retry_count -= 1) < 0
            # ... otherwise sleep a bit and retry.
            retries_performed += 1
            log("#{self.class.name}: Performing retry ##{retries_performed} caused by: #{e.class.name}: #{e.message}")
            sleep(connection_retry_delay) unless connection_retry_delay._blank?
            connection_retry_delay *= 2
            retry
          end
        end


        # Saves HTTP Response into data hash.
        #
        # @param [Net::HTTPResponse] response
        #
        # @return [void]
        #
        def set_http_response(response)
          @data[:response][:instance] = HTTPResponse.new(
            response.code,
            response.body.is_a?(IO) ? nil : response.body,
            response.to_hash,
            response
          )
          nil
        end


        # Net::HTTP::Persistent believes that it can retry on any GET call what is not true for
        # Query like API clouds (Amazon, CloudStack, Euca, etc).
        # The solutions is to monkeypatch  Net::HTTP::Persistent#can_retry? so that is returns
        # Net::HTTP::Persistent#retry_change_requests.
        #
        # @param [Net::HTTP::Persistent] connection
        #
        # @return [void]
        #
        def disable_net_http_persistent_retries(connection)
          connection.retry_change_requests = false
          # Monkey patch this connection instance only.
          def connection.can_retry?(*args)
            false
          end
          nil
        end

      end 
    end
  end
end
