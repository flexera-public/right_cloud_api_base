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
      
      class RightHttpConnectionProxy
        @@storage = {}

        def self.storage
          @@storage
        end

        # Remove dead threads/fibers from the storage
        def self.clean_storage
          Utils::remove_dead_fibers_and_threads_from_storage(storage)
        end

        class Error < CloudApi::Error
        end

        # Performs an HTTP request.
        #
        # @param [Hash] data The API request +data+ storage.
        #   See {RightScale::CloudApi::ApiManager.initialize_api_request_options} code for its explanation.
        #
        def request(data)
          require "right_http_connection"

          @data = data
          @data[:response] = {}
          # Create a connection
          @uri = @data[:connection][:uri].dup

          # Create/Get RightHttpConnection instance
          remote_endpoint       = current_endpoint
          right_http_connection = current_connection

          # Register a callback to close current connection
          @data[:callbacks][:close_current_connection] = Proc::new{|reason| close_connection(remote_endpoint, reason); log "Current connection closed: #{reason}" }

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

          # Set all the options are suported by RightHttpConnection (if they are)
          http_connection_data = {
            :server    => @uri.host,
            :port      => @uri.port,
            :protocol  => @uri.scheme,
            :request   => http_request,
            :exception => ConnectionError
          }

          # Set all required options
          http_connection_data[:logger]                       = @data[:options][:cloud_api_logger].logger
          http_connection_data[:user_agent]                   = @data[:options][:connection_user_agent]   if @data[:options].has_key?(:connection_user_agent)
          http_connection_data[:ca_file]                      = @data[:options][:connection_ca_file]      if @data[:options].has_key?(:connection_ca_file)
          http_connection_data[:http_connection_retry_count]  = @data[:options][:connection_retry_count]  if @data[:options].has_key?(:connection_retry_count)
          http_connection_data[:http_connection_read_timeout] = @data[:options][:connection_read_timeout] if @data[:options].has_key?(:connection_read_timeout)
          http_connection_data[:http_connection_open_timeout] = @data[:options][:connection_open_timeout] if @data[:options].has_key?(:connection_open_timeout)
          http_connection_data[:http_connection_retry_delay]  = @data[:options][:connection_retry_delay]  if @data[:options].has_key?(:connection_retry_delay)
          http_connection_data[:raise_on_timeout]             = @data[:options][:abort_on_timeout]        if @data[:options][:abort_on_timeout]
          http_connection_data[:cert]                         = @data[:credentials][:cert]                if @data[:credentials].has_key?(:cert)
          http_connection_data[:key]                          = @data[:credentials][:key]                 if @data[:credentials].has_key?(:key)
            
          #log "HttpConnection request: #{http_connection_data.inspect}"

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
              response = right_http_connection.request(http_connection_data) do |res|
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
              right_http_connection.finish(e.message)
              raise e
            end
          else
            # Things are simple if there is no any block
            response = right_http_connection.request(http_connection_data)
          end

          @data[:response][:instance] = HTTPResponse::new( response.code,
                                                           response.body,
                                                           response.to_hash,
                                                           response )

  #        # HACK: KD 
  #        # 
  #        # When one uploads a file with pos > 0 and 'content-length' != File.size - pos
  #        # then the next request through this connection fails with 400 or 505...
  #        # It seems that it expects the file to be read until EOF.
  #        # 
  #        # KIlling the current connection seems to help but it is not good...
  #        #
  #        if @data[:request][:instance].body_stream #&& !@data[:request][:instance].body_stream.eof
  #          pp @data[:request][:instance].body_stream.pos
  #          log "closing current connection because of an issue when an IO object is not read until EOF"
  #          @connection.finish
  #        end
        end
        
        def log(message)     
          @data[:options][:cloud_api_logger].log(message, :right_http_connection_proxy)
        end
        
        #----------------------------
        # HTTP Connections handling
        #----------------------------

        def storage # :nodoc:
          @@storage[Utils::current_thread_and_fiber] ||= {}
        end

        def current_endpoint # :nodoc:
          "#{@uri.scheme}://#{@uri.host}:#{@uri.port}"
        end

        def close_connection(endpoint, reason='') # :nodoc:
          return nil unless storage[endpoint]

          log "Destroying RightHttpConnection to #{endpoint}, reason: #{reason}"
          storage[endpoint][:connection].finish(reason)
        rescue => e
          log "Exception in close_connection: #{e.class.name}: #{e.message}"
        ensure
          storage.delete(endpoint) if endpoint
        end

        INACTIVE_LIFETIME_LIMIT = 900 # seconds

        # Delete out-of-dated connections for current Thread/Fiber
        def clean_outdated_connections
          life_time_scratch = Time::now - INACTIVE_LIFETIME_LIMIT
          storage.each do |endpoint, connection|
            if connection[:last_used_at] < life_time_scratch
              close_connection(endpoint, 'out-of-date')
            end
          end
        end

        # Expire the connection if it has expired.
        def current_connection # :nodoc:
          # Remove dead threads/fibers from the storage
          self.class::clean_storage
          # Delete out-of-dated connections
          clean_outdated_connections
          # Get current_connection
          endpoint = current_endpoint
          unless storage[endpoint]
            storage[endpoint] = {}
            storage[endpoint][:connection] = Rightscale::HttpConnection.new( :exception => CloudError, 
                                                                             :logger    => @data[:options][:cloud_api_logger].logger )
            log "Creating RightHttpConection to #{endpoint.inspect}"
          else
            log "Reusing RightHttpConection to #{endpoint.inspect}"
          end
          storage[endpoint][:last_used_at] = Time::now
          storage[endpoint][:connection]
        end
      end
 
    end
  end
end
