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

        def log(message)
          @data[:options][:cloud_api_logger].log(message, :net_http_persistent_proxy)
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
          connection = Net::HTTP::Persistent::new 'right_cloud_api_gem'

          # Create a real HTTP request
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
          @data[:callbacks][:close_current_connection] = Proc::new {|reason| connection.shutdown; log "Current connection closed: #{reason}" }
          
          # Set all required options
          http_request['user-agent'] ||= @data[:options][:connection_user_agent]   if @data[:options].has_key?(:connection_user_agent)
          connection.ca_file           = @data[:options][:connection_ca_file]      if @data[:options].has_key?(:connection_ca_file)
          connection.read_timeout      = @data[:options][:connection_read_timeout] if @data[:options].has_key?(:connection_read_timeout)
          connection.open_timeout      = @data[:options][:connection_open_timeout] if @data[:options].has_key?(:connection_open_timeout)
          connection.certificate       = @data[:credentials][:cert]                if @data[:credentials].has_key?(:cert)
          connection.private_key       = @data[:credentials][:key]                 if @data[:credentials].has_key?(:key)
  
          # --- BEGIN HACK ---
          # KD: Hack to deal with :abort_on_timeout option (override Net::HTTP::Persistent#can_retry? method)
          connection.retry_change_requests = (data[:options].has_key?(:abort_on_timeout) && !@data[:options][:abort_on_timeout]) || true

          # We need a way to tell to Net::HTTP::Persistent that we wanna make one extra retry attempt
          # even when Net::HTTP::Persistent does not think so. On eof the solutions is to set
          # Net::HTTP::Persistent#retry_change_requests to true and owerride Net::HTTP::Persistentcan_retry?
          # so that is returns Net::HTTP::Persistent#retry_change_requests.
          #
          # P.S. Net::HTTP::Persisten supports only 1 retry
          def connection.can_retry?(req)
            retry_change_requests
          end
          # --- END HACK ---

          log "HttpConnection request: #{connection.inspect}"

          # Make a request:
          block = @data[:vars][:system][:block]
          if block
            # If block is given - pass there all the chunks of a response and stop
            # (dont do any parsing, analysing etc)
            # 
            # TRB 9/17/07 Careful - because we are passing in blocks, we get a situation where
            # an exception may get thrown in the block body (which is high-level
            # code either here or in the application) but gets caught in the
            # low-level code of HttpConnection.  The solution is not to let any
            # exception escape the block that we pass to HttpConnection::request.
            # Exceptions can originate from code directly in the block, or from user
            # code called in the other block which is passed to response.read_body.
            # 
            # TODO: the suggested fix for RightHttpConnection if to catch 
            # Interrupt and SystemCallError instead of Exception in line 402
            response = nil
            begin
              block_exception = nil
              # Response.body will be a Net::ReadAdapter instance here - it cant be read as a string.
              # WEB: On its own, Net::HTTP causes response.body to be a Net::ReadAdapter when you make a request with a block 
              # that calls read_body on the response.
              response = connection.request(uri, http_request) do |res|
                begin
                  # Update temp response
                  @data[:response][:instance] = HTTPResponse::new( res.code,
                                                                   nil,
                                                                   res.to_hash,
                                                                   res )
                  res.read_body(&block) if res.is_a?(Net::HTTPSuccess)
                rescue Exception => e
                  block_exception = e
                  break
                end
              end
              raise block_exception if block_exception
            rescue Exception => e
              connection.shutdown
              raise ConnectionError::new e.message
            end
          else
            # Things are simple if there is no any block
            begin
              response = connection.request(uri, http_request)
            rescue Exception => e
              connection.shutdown
              raise ConnectionError::new e.message
            end
          end

          @data[:response][:instance] = HTTPResponse::new( response.code,
                                                           response.body,
                                                           response.to_hash,
                                                           response )
        end
      end 
    end
  end
end
