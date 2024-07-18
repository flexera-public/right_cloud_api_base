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
        OTHER_ERRORS   = /SocketError|EOFError|SSL_connect|EAFNOSUPPORT/

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
          require 'net/http/persistent'
          # Initialize things:
          @data            = data
          @data[:response] = {}
          # Create a new HTTP request instance
          http_request = create_new_http_request
          # Create and tweak Net::HTTP::Persistent instance
          connection   = create_new_persistent_connection
          # Make a request
          begin
            make_request_with_retries(connection, @data[:connection][:uri], http_request)
          rescue StandardError => e
            raise(ConnectionError, e.message)
          ensure
            connection.shutdown
          end
        end

        # Creates a new connection.
        #
        # There is a bug in Net::HTTP::Persistent where it allows you to reuse an SSL connection
        # created by another instance of Net::HTTP::Persistent, if they share the same app name.
        # To avoid this, every instance of Net::HTTP::Persistent should have its own 'name'.
        #
        # If your app does not care about SSL certs and keys (like AWS does) then it is safe to
        # reuse connections.
        #
        # see https://github.com/drbrain/net-http-persistent/issues/45
        #
        def create_new_persistent_connection
          app_name = if @data[:options][:connection_ca_file] ||
                        @data[:credentials][:cert]           ||
                        @data[:credentials][:key]
                       'right_cloud_api_gem_%s' % Utils.generate_token
                     else
                       'right_cloud_api_gem'
                     end
          connection = Net::HTTP::Persistent.new(name: app_name)
          set_persistent_connection_options!(connection)
          # Register a callback to close current connection
          @data[:callbacks][:close_current_connection] = proc do |reason|
            connection.shutdown
            log "Current connection closed: #{reason}"
          end
          connection
        end

        # Sets connection_ca_file, connection_read_timeout, connection_open_timeout,
        # connection_verify_mode and SSL cert and key
        #
        # @param [Net::HTTP::Persistent] connection
        #
        # @return [Net::HTTP::Persistent]
        #
        def set_persistent_connection_options!(connection)
          %i[ca_file read_timeout open_timeout verify_mode].each do |connection_method|
            connection_option_name = "connection_#{connection_method}".to_sym
            next unless @data[:options].has_key?(connection_option_name)

            connection.__send__("#{connection_method}=", @data[:options][connection_option_name])
          end
          if @data[:credentials].has_key?(:cert)
            connection.cert = OpenSSL::X509::Certificate.new(@data[:credentials][:cert])
          end
          connection.key = OpenSSL::PKey::RSA.new(@data[:credentials][:key]) if @data[:credentials].has_key?(:key)
          connection.use_ssl = true
          connection.ssl_version = :TLSv1_2 # using TLSv1_2
          # connection.ciphers = ['RC4-SHA']

          connection
        end

        # Creates and configures a new HTTP request object
        #
        # @return [Net::HTTPRequest]
        #
        def create_new_http_request
          # Create a new HTTP request instance
          request_spec = @data[:request][:instance]
          http_class   = "Net::HTTP::#{request_spec.verb._camelize}"
          http_request = http_class._constantize.new(request_spec.path)

          Merb.logger.info "Net::HTTP request url: #{@data[:connection][:uri]}"
          Merb.logger.info "Net::HTTP request body: #{request_spec.body}"

          # Set the request body
          if request_spec.is_io?
            http_request.body_stream = request_spec.body
          else
            http_request.body = request_spec.body
          end
          # Copy headers
          request_spec.headers.each { |header, value| http_request[header] = value }
          # Save the new request
          request_spec.raw = http_request
          # Set user-agent
          if @data[:options].has_key?(:connection_user_agent)
            http_request['user-agent'] ||= @data[:options][:connection_user_agent]
          end
          http_request
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
                if response.is_a?(Net::HTTPSuccess)
                  set_http_response(response, :skip_body)
                  response.read_body(&block)
                else
                  set_http_response(response)
                end
              end
            else
              # Set text response
              response = connection.request(uri, http_request)
              set_http_response(response)
            end
            nil
          rescue OpenSSL::SSL::SSLError => e
            custom_error_msg = "OpenSSLError, no more retries: #{e.class.name}: #{e.message}"
            raise_debugging_messages(uri, http_request, response, e, custom_error_msg)

            # no retries
          rescue StandardError => e
            # Parse both error message and error classname; for some errors it's not enough to parse only a message
            custom_error_msg = "#{e.class.name}: #{e.message}"
            # Initialize new error with full message including class name, so gw can catch it now
            custom_error = Error.new(custom_error_msg)
            # Fail if it is an unknown error
            raise(custom_error) unless custom_error_msg[TIMEOUT_ERRORS] || custom_error_msg[OTHER_ERRORS]
            # Fail if it is a Timeout and timeouts are banned
            raise(custom_error) if custom_error_msg[TIMEOUT_ERRORS] && !!@data[:options][:abort_on_timeout]
            # Fail if there are no retries left...
            raise(custom_error) if (connection_retry_count -= 1) < 0

            raise_debugging_messages(uri, http_request, response, e)

            # ... otherwise sleep a bit and retry.
            retries_performed += 1
            log("#{self.class.name}: Performing retry ##{retries_performed} caused by: #{e.class.name}: #{e.message}")
            sleep(connection_retry_delay) unless connection_retry_delay._blank?
            connection_retry_delay *= 2

            retry
          end
        end

        # remove this method
        def raise_debugging_messages(uri, http_request, response, e, _custom_message = nil)
          # Remove this
          # this is for debugging purposes
          connection_errors = []
          connection_errors << Error.new('ConnectionErrors::Errors raised during connection attempt')
          connection_errors << Error.new("ConnectionErrors::Message: #{e}")
          connection_errors << Error.new("ConnectionErrors::CustomMessage: #{_custom_message}") if _custom_message
          connection_errors << Error.new("ConnectionErrors::URI: #{uri}") if uri

          if http_request&.body
            connection_errors << Error.new("ConnectionErrors::http_request::body: #{http_request.body}")
          end
          if http_request&.body_stream
            connection_errors << Error.new("ConnectionErrors::http_request::body_stream: #{http_request.body_stream}")
          end
          if http_request
            connection_errors << Error.new("ConnectionErrors::http_request::method: #{http_request.method}")
          end
          connection_errors << Error.new("ConnectionErrors::response_body: #{response&.body}") if response
          connection_errors << Error.new("ConnectionErrors::error_backtrace: #{e.backtrace}")

          raise(connection_errors.join("\n")) if connection_errors.any?
          # end of debugging block
        end

        # Saves HTTP Response into data hash.
        #
        # @param [Net::HTTPResponse] response
        #
        # @return [void]
        #
        def set_http_response(response, skip_body = false)
          @data[:response][:instance] = HTTPResponse.new(
            response.code,
            skip_body ? nil : response.body,
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
          def connection.can_retry?(*_args)
            false
          end
          nil
        end
      end
    end
  end
end
