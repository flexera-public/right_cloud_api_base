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

    # The class is the parent class for all the cloud based thread-non-safe managers
    #
    # @api public
    #
    # It implements all the +generic+ functionalities the cloud specific managers share.
    #
    class ApiManager

      # Log filters set by default
      DEFAULT_LOG_FILTERS = [
        :connection_proxy,
        :request_generator,
        :request_generator_body,
        :response_analyzer,
        :response_analyzer_body_error,
        :response_parser,
      ]


      # Default Error
      class Error < CloudApi::Error
      end


      # Options reader
      #
      # @return [Hash] The list of class level set options.
      # @example
      #  # no example
      #
      def self.options
        @options ||= {}
      end


      # Options setter
      #
      # @param  [Hash] options
      # @return [void]
      #
      # @example
      #  module RightScale
      #    module CloudApi
      #      module AWS
      #        class ApiManager < CloudApi::ApiManager
      #          set :response_error_parser => Parser::AWS::ResponseErrorV1
      #          set :cache => true
      #          ...
      #        end
      #      end
      #    end
      #  end
      #
      def self.set(opts)
        opts.each { |key, value| self.options[key] = value }
        nil
      end


      # Returns a list of routines the manager invokes while processing API request
      #
      # @return [Array] An array of RightScale::CloudApi::Routine.
      # @example
      #  # no example
      #
      def self.routines
        @routines ||= []
      end


      # Add routine of the given tipe into the list of API processing routines
      #
      # @param  [RightScale::CloudApi::Routine] routines A set of routines.
      # @return [Array] The current set of routines.
      # @example
      #  # no example
      #
      def self.set_routine(*new_routines)
        new_routines.flatten.each do |routine|
          self.routines << routine
          # If a routine has ClassMethods module defined then extend the current class with those methods.
          # We use this to add class level helper methods like: error_pattern or cache_pattern
          self.extend routine::ClassMethods if defined?(routine::ClassMethods)
        end
        self.routines
      end

      # Return a set of system vars (ignore this attribute)
      #
      # @return [Hash]
      # @example
      #  # no example
      #
      attr_reader :data

      # Return a set of system routines (ignore this attribute)
      #
      # @return [Array]
      # @example
      #  # no example
      #
      attr_reader :routines


      # Constructor
      #
      # @param [Hash]    credentials  Cloud credentials.
      # @param [String]  endpoint     API endpoint.
      # @param [Hash]    options      A set of options (see below).
      #
      # @option options [Boolean]  :allow_endpoint_params
      #   When the given endpoint has any set of URL params they will not be ignored but will
      #   be added to every API request.
      #
      # @option options [Boolean]  :abort_on_timeout
      #   When set to +true+ the gem does not perform a retry call when there is a connection
      #   timeout.
      #
      # @option options [String]  :api_version
      #   The required cloud API version if it is different from the default one.
      #
      # @option options [Class]  :api_wrapper
      #   The Query-like API wrapper module that provides a set of handy methods to drive
      #   REST APIs (see {RightScale::CloudApi::Mixin::QueryApiPatterns::ClassMethods})
      #
      # @option options [Boolean]  :cache
      #   Cache cloud responses when possible so that we don't parse them again if cloud
      #   response does not change (see cloud specific ApiManager definition).
      #
      # @option options [Hash]  :cloud
      #  A set of cloud specific options. See custom cloud specific ApiManagers for better
      #  explanation.
      #
      # @option options [String]  :connection_ca_file
      #   CA certificate for SSL connection.
      #
      # @option options [Integer]  :connection_open_timeout
      #   Connection open timeout (in seconds).
      #
      # @option options [String]  :connection_proxy
      #   Connection proxy class (when it need to be different from the default one).
      #   Only RightScale::CloudApi::ConnectionProxy::NetHttpPersistentProxy is supported so far.
      #
      # @option options [Integer]  :connection_read_timeout
      #   Connection read timeout (in seconds).
      #
      # @option options [Integer]  :connection_retry_count
      #   Max number of retries to when unable to establish a connection to API server
      #
      # @option options [Integer]  :connection_retry_delay
      #  Defines how long we wait on a low level connection error (in seconds)
      #
      # @option options [Integer]  :connection_verify_mode
      #  SSL connection cert check: either OpenSSL::SSL::VERIFY_PEER (default) or
      #  OpenSSL::SSL::VERIFY_NONE
      #
      # @option options [Hash]  :creds
      #   A set of optional extra creds a cloud may require
      #   (see right_cloud_stack_api gem which supports :tenant_name and :tenant_id)
      #
      # @option options [Hash]  :headers
      #   A set of request headers to be added to every API call.
      #
      # @option options [Logger]  :logger
      #   Current logger. If is not provided then it logs to STDOUT. When if nil is given it
      #   logs to '/dev/nul'.
      #
      # @option options [Symbol]  :log_filter_patterns
      #   A set of log filters that define what to log (see {RightScale::CloudApi::CloudApiLogger}).
      #
      # @option options [Hash]  :params
      #   A set of URL params to be sent with the API request.
      #
      # @option options [Boolean,String]  :random_token
      #   Some clouds API cache their responses when they receive the same request again
      #   and again, even when we are sure that cloud response mush have changed. To deal
      #   with this we can add a random parameter to an API call to trick the remote API.
      #   When :random_token is set to +true+ it adds an extra param with name 'rsrcarandomtoken'
      #   and a random value to every single API request. When :random_token is a String then
      #   the gem uses it as the random param name.
      #
      # @option options [Boolean] :raw_response
      #   By default the gem parses all XML and JSON responses and returns them as ruby Hashes.
      #   Sometimes it is not what one would want (Amazon S3 GetObject for example).
      #   Setting this option to +true+ forces the gem to return a not parsed response. 
      #
      # @option options [Class]  :response_error_parser
      #   API response parser in case of error (when it needs to be different from the default one).
      #
      # @option options [Symbol]  :xml_parser
      #   XML parser (:sax | :rexml are supported).
      #
      # @option options [Proc]  :before_process_api_request_callback
      #   The callback is called before every API request (may be helpful when debugging things).
      #
      # @option options [Proc]  :before_routine_callback
      #   The callback is called before each routine is executed.
      #
      # @option options [Proc]  :after_routine_callback
      #   The callback is called after each routine is executed.
      #
      # @option options [Proc]  :after_process_api_request_callback
      #   The callback is called after the API request completion.
      #
      # @option options [Proc]  :before_retry_callback
      #   The callback is called if a retry attempt is required.
      #
      # @option options [Proc]  :before_redirect_callback
      #   The callback is called when a redirect is detected.
      #
      # @option options [Proc]  :stat_data_callback
      #   The callback is called when stat data for the current request is ready. 
      #
      # @raise [Rightscale::CloudApi::ApiManager::Error]
      #   If no credentials have been set or the endpoint is blank.
      #
      # @example
      #   # See cloud specific gems for use case.
      #
      # @see Manager
      #
      def initialize(credentials, endpoint, options={})
        @endpoint     = endpoint
        @credentials  = credentials.merge!(options[:creds] || {})
        @credentials.each do |key, value|
          fail(Error, "Credential #{key.inspect} cannot be empty") unless value
        end
        @options      = options
        @options[:cloud] ||= {}
        @with_options = []
        @with_headers = {}
        @routines     = []
        @storage      = {}
        @options[:cloud_api_logger] = RightScale::CloudApi::CloudApiLogger.new(@options , DEFAULT_LOG_FILTERS)
        # Try to set an API version when possible
        @options[:api_version] ||= "#{self.class.name}::DEFAULT_API_VERSION"._constantize rescue nil
        # Load routines
        routine_classes = (Utils.inheritance_chain(self.class, :routines).select{|rc| !rc._blank?}.last || [])
        @routines       = routine_classes.map{ |routine_class| routine_class.new }
        # fail Error::new("Credentials must be set") if @credentials._blank?
        fail Error::new("Endpoint must be set")    if @endpoint._blank?
        # Try to wrap this manager with the handy API methods if possible using [:api_wrapper, :api_version, 'default']
        # (but do nothing if one explicitly passed :api_wrapper => nil )
        unless @options.has_key?(:api_wrapper) && @options[:api_wrapper].nil?
          # And then wrap with the most recent or user's wrapper
          [ @options[:api_wrapper], @options[:api_version], 'default'].uniq.each do |api_wrapper|
            break if wrap_api_with(api_wrapper, false)
          end
        end
      end


      # Main API request entry point
      #
      # @api private
      #
      # @param [String,Symbol] verb          HTTP verb: :get, :post, :put, :delete, etc.
      # @param [String]        relative_path Relative URI path.
      # @param [Hash]          opts          A set of extra options.
      #
      # @option options [Hash]  :params
      #   A set of URL parameters.
      #
      # @option options [Hash]  :headers
      #   A set of HTTP headers.
      #
      # @option options [Hash]  :options
      #   A set of extra options: see {#initialize} method for them.
      #
      # @option options [Hash,String] :body
      #   The request body. If Hash is passed then it will convert it into String accordingly to
      #   'content-type' header.
      #
      # @option options [String]  :endpoint
      #   An endpoint if it is different from the default one.
      #
      # @return [Object]
      #
      # @example
      #  # The method should not be used directly: use *api* method instead.
      #
      # @yield [String] If a block is given it will call it on every chunk of data received from a socket.
      #
      def process_api_request(verb, relative_path, opts={}, &block)
        # Add a unique-per-request log prefix to every logged line.
        cloud_api_logger.set_unique_prefix
        # Initialize @data variable and get a final set of API request options.
        options = initialize_api_request_options(verb, relative_path, opts, &block)
        # Before_process_api_request_callback.
        invoke_callback_method(options[:before_process_api_request_callback], :manager => self)
        # Main loop
        loop do
          # Start a new stat session.
          stat = {}
          @data[:stat][:data] << stat
          # Reset retry attempt flag.
          retry_attempt = false
          # Loop through all the required routes.
          routines.each do |routine|
            # Start a new stat record for current routine.
            routine_name       = routine.class.name
            stat[routine_name] = {}
            stat[routine_name][:started_at] = Time.now.utc
            begin
              # Set routine data
              routine.reset(data)
              # Before_routine_callback.
              invoke_callback_method(options[:before_routine_callback],
                                     :routine => routine,
                                     :manager => self)
              # Process current routine.
              routine.process
              # After_routine_callback.
              invoke_callback_method(options[:after_routine_callback],
                                     :routine => routine,
                                     :manager => self)
              # If current routine reported the API request is done we should stop and skip all the
              # rest routines
              break if data[:vars][:system][:done]
            rescue RetryAttempt
              invoke_callback_method(options[:after_routine_callback],
                                     :routine => routine,
                                     :manager => self,
                                     :retry   => true)
              # Set a flag that would notify the exterlan main loop there is a retry request received.
              retry_attempt = true
              # Break the routines loop and exit into the main one.
              break
            ensure
              # Complete current stat session
              stat[routine_name][:time_taken] = Time.now.utc - stat[routine_name][:started_at]
            end
          end
          # Make another attempt from the scratch or...
          redo if retry_attempt
          # ...stop and report the result.
          break
        end
        # After_process_api_request_callback.
        invoke_callback_method(options[:after_process_api_request_callback], :manager => self)
        data[:result]
      rescue => error
        # Invoke :after error callback
        invoke_callback_method(options[:after_error_callback], :manager => self, :error => error)
        fail error
      ensure
        # Remove the unique-per-request log prefix.
        cloud_api_logger.reset_unique_prefix
        # Complete stat data and invoke its callback.
        @data[:stat][:time_taken] = Time.now.utc - @data[:stat][:started_at] if @data[:stat]
        invoke_callback_method(options[:stat_data_callback], :manager => self, :stat => self.stat, :error => error)
      end
      private :process_api_request


      # Initializes the @data variable and builds the request options
      #
      # @api private
      #
      # @param [String,Symbol] verb          HTTP verb: :get, :post, :put, :delete, etc.
      # @param [String]        relative_path Relative URI path.
      # @param [Hash]          opts          A set of extra options.
      #
      # @option options [Hash]        :params  A set of URL parameters.
      # @option options [Hash]        :headers A set of HTTP headers.
      # @option options [Hash]        :options A set of extra options: see {#initialize} method for them.
      # @option options [Hash,String] :body    The request body. If Hash is passed then it will
      #   convert it into String accordingly to 'content-type' header.
      #
      # @yield [String] If a block is given it will call it on every chunk of data received from a socket.
      #
      # @return [Any] The result of the request (usually a Hash or a String instance).
      #
      def initialize_api_request_options(verb, relative_path, opts, &block)
        options       = {}
        options_chain = Utils.inheritance_chain(self.class, :options, @options, *(@with_options + [opts[:options]]))
        options_chain.each{ |o| options.merge!(o || {}) }
        # Endpoint
        endpoint = options[:endpoint] || @endpoint
        # Params
        params = {}
        params.merge!(Utils::extract_url_params(endpoint))._stringify_keys if options[:allow_endpoint_params]
        params.merge!(options[:params] || {})._stringify_keys
        params.merge!(opts[:params] || {})._stringify_keys
        # Headers
        headers = (options[:headers] || {})._stringify_keys
        headers.merge!(@with_headers._stringify_keys)
        headers.merge!( opts[:headers] || {})._stringify_keys
        # Make sure the endpoint's schema is valid.
        parsed_endpoint = ::URI::parse(endpoint)
        unless [nil, 'http', 'https'].include? parsed_endpoint.scheme
          fail Error.new('Endpoint parse failed - invalid scheme')
        end
        # Options: Build the initial data hash
        @data = {
          :options     => options.dup,
          :credentials => @credentials.dup,
          :connection  => { :uri           => parsed_endpoint },
          :request     => { :verb          => verb.to_s.downcase.to_sym,
                            :relative_path => relative_path,
                            :headers       => HTTPHeaders::new(headers),
                            :body          => opts[:body],
                            :orig_body     => opts[:body],  # keep here a copy of original body (Routines may change the real one, when it is a Hash)
                            :params        => params,
                            :orig_params   => params.dup }, # original params without any signatures etc
          :vars        => { :system  => { :started_at => Time::now.utc,
                                          :storage    => @storage,
                                          :block      => block }
                          },
          :callbacks   => { },
          :stat        => {
            :started_at => Time::now.utc,
            :data       => [ ],
          },
        }
        options
      end
      private :initialize_api_request_options


      # A helper method for invoking callbacks
      #
      # @api private
      #
      # The method checks if the given Proc exists and invokes it with the given set of arguments.
      # In the case when proc==nil the method does nothing.
      #
      # @param [Proc] proc The callback.
      # @param [Any] args A set of callback method arguments.
      #
      # @return [void]
      #
      def invoke_callback_method(proc, *args) # :nodoc:
        proc.call(*args) if proc.is_a?(Proc)
      end
      private :invoke_callback_method


      # Returns the current logger
      #
      # @return [RightScale::CloudApi::CloudApiLogger]
      # @example
      #   # no example
      #
      def cloud_api_logger
        @options[:cloud_api_logger]
      end


      # Returns current statistic
      #
      # @return [Hash]
      #
      # @example
      #   # Simple case:
      #   amazon.DescribeVolumes #=> [...]
      #   amazon.stat #=>
      #     {:started_at=>2014-01-03 19:09:13 UTC,
      #      :time_taken=>2.040465903,
      #      :data=>
      #       [{"RightScale::CloudApi::RetryManager"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>1.7136e-05},
      #         "RightScale::CloudApi::RequestInitializer"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>7.405e-06},
      #         "RightScale::CloudApi::AWS::RequestSigner"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>0.000140031},
      #         "RightScale::CloudApi::RequestGenerator"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>4.7781e-05},
      #         "RightScale::CloudApi::RequestAnalyzer"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>3.1789e-05},
      #         "RightScale::CloudApi::ConnectionProxy"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>2.025818663},
      #         "RightScale::CloudApi::ResponseAnalyzer"=>
      #          {:started_at=>2014-01-03 19:09:15 UTC, :time_taken=>0.000116668},
      #         "RightScale::CloudApi::CacheValidator"=>
      #          {:started_at=>2014-01-03 19:09:15 UTC, :time_taken=>1.9225e-05},
      #         "RightScale::CloudApi::ResponseParser"=>
      #          {:started_at=>2014-01-03 19:09:15 UTC, :time_taken=>0.014059933},
      #         "RightScale::CloudApi::ResultWrapper"=>
      #          {:started_at=>2014-01-03 19:09:15 UTC, :time_taken=>4.4907e-05}}]}
      #
      # @example
      #   # Using callback:
      #   STAT_DATA_CALBACK = lambda do |args|
      #     puts "Error: #{args[:error].class.name}" if args[:error]
      #     pp   args[:stat]
      #   end
      #
      #   amazon = RightScale::CloudApi::AWS::EC2::Manager::new(
      #     ENV['AWS_ACCESS_KEY_ID'],
      #     ENV['AWS_SECRET_ACCESS_KEY'],
      #     endpoint || ENV['EC2_URL'],
      #     :stat_data_callback => STAT_DATA_CALBACK)
      #
      #   amazon.DescribeVolumes #=> [...]
      #
      #     # >> Stat data callback's output <<:
      #     {:started_at=>2014-01-03 19:09:13 UTC,
      #      :time_taken=>2.040465903,
      #      :data=>
      #       [{"RightScale::CloudApi::RetryManager"=>
      #          {:started_at=>2014-01-03 19:09:13 UTC, :time_taken=>1.7136e-05},
      #          ...
      #         "RightScale::CloudApi::ResultWrapper"=>
      #          {:started_at=>2014-01-03 19:09:15 UTC, :time_taken=>4.4907e-05}}]}
      #
      def stat
        @data && @data[:stat]
      end


      # Returns the last request object
      #
      # @return [RightScale::CloudApi::HTTPRequest]
      # @example
      #  # no example
      #
      def request
        @data && @data[:request] && @data[:request][:instance]
      end


      # Returns the last response object
      #
      # @return [RightScale::CloudApi::HTTPResponse]
      # @example
      #  # no example
      #
      def response
        @data && @data[:response] && @data[:response][:instance]
      end


      # The method is just a wrapper around process_api_request
      #
      # But this behavour can be overriden by sub-classes.
      #
      # @param [Any] args See *process_api_request* for the current ApiManager.
      #
      # @yield [String] See *process_api_request* for the current ApiManager.
      #
      # @return [Any] See *process_api_request* for the current ApiManager.
      # 
      # @example
      #  # see cloud specific gems
      #
      def api(*args, &block)
        process_api_request(*args, &block)
      end


      # Defines a set of *get*, *post*,  *put*, *head*, *delete*, *patch* helper methods.
      # All the methods are very simple wrappers aroung the *api* method. Whatever you would feed to
      # *api* method you can feed to these ones except for the very first parameter :verb which
      # is not required.
      #
      # @example
      #   s3.api(:get, 'my_bucket')
      #   # is equivalent to
      #   s3.get('my_bucket')
      #
      HTTP_VERBS = [ :get, :post, :put, :head, :delete, :patch  ]
      HTTP_VERBS.each do |http_verb|
        eval <<-EOM
          def #{http_verb}(*args, &block)
            api(__method__.to_sym, *args, &block)
          end
        EOM
      end


      # Sets temporary set of options
      #
      # The method takes a block and all the API calls made inside it will have the given set of
      # extra options. The method supports nesting.
      #
      # @param [Hash] options The set of options. See {#initialize} methos for the possible options.
      # @return [void]
      # @yield [] All the API call made in the block will have the provided options.
      #
      # @example
      #   # The example does not make too much sense - it just shows the idea.
      #   ec2 = RightScale::CloudApi::AWS::EC2.new(key, secret_key, :api_version => '2009-01-01')
      #   # Describe all the instances against API '2009-01-01'.
      #   ec2.DescribeInstances
      #   ec2.with_options(:api_version => '2012-01-01') do
      #     # Describe all the instances against API '2012-01-01'.
      #     ec2.DescribeInstances
      #     # Describe and stop only 2 instances.
      #     ec2.with_options(:params => { 'InstanceId' => ['i-01234567', 'i-76543210']  }) do
      #       ec2.DescribeInstances
      #       ec2.StopInstances
      #     end
      #   end
      #
      def with_options(options={}, &block)
        @with_options << (options || {})
        block.call
      ensure
        @with_options.pop
      end


      # Sets temporary sets of HTTP headers
      #
      # The method takes a block and all the API calls made inside it will have the given set of
      # headers.
      #
      # @param [Hash] headers The set oh temporary headers.
      # @option options [option_type] option_name option_description
      #
      # @return [void]
      #
      # @yield [] All the API call made in the block will have the provided headers.
      #
      # @example
      #   # The example does not make too much sense - it just shows the idea.
      #   ec2 = RightScale::CloudApi::AWS::EC2.new(key, secret_key, :api_version => '2009-01-01')
      #   ec2.with_header('agent' => 'mozzzzzillllla') do
      #     # the header is added to every request below
      #     ec2.DescribeInstances
      #     ec2.DescribeImaneg
      #     ec2.DescribeVolumes
      #   end
      #
      def with_headers(headers={}, &block)
        @with_headers = headers || {}
        block.call
      ensure
        @with_headers = {}
      end


      # Wraps the Manager with handy API helper methods
      #
      # The wrappers are not necessary but may be very helpful for REST API related clouds such
      # as Amazon S3, OpenStack/Rackspace or Windows Azure.
      #
      # @param [Module,String] api_wrapper The wrapper module or a string that would help to
      # identify it.
      #
      # @return [void]
      #
      # @raise [RightScale::CloudApi::ApiManager::Error] If an unexpected parameter is passed.
      # @raise [RightScale::CloudApi::ApiManager::Error] If the requested wrapper does not exist.
      #
      # If string is passed:
      #
      #  OpenStack: 'v1.0'       #=> 'RightScale::CloudApi::OpenStack::Wrapper::V1_0'
      #  EC2:       '2011-05-08' #=> 'RightScale::CloudApi::AWS::EC2::Wrapper::V2011_05_08'
      #
      # @example
      #  # ignore the method
      #
      def wrap_api_with(api_wrapper=nil, raise_if_not_exist=true) # :nodoc:
        return if api_wrapper._blank?
        # Complain if something unexpected was passed.
        fail Error.new("Unsupported wrapper: #{api_wrapper.inspect}") unless api_wrapper.is_a?(Module) || api_wrapper.is_a?(String)
        # If it is not a module - make it be the module
        unless api_wrapper.is_a?(Module)
          # If the String starts with a digit the prefix it with 'v'.
          api_wrapper = "v" + api_wrapper if api_wrapper.to_s[/^\d/]
          # Build the module name including the parent namespaces.
          api_wrapper = "#{self.class.name.sub(/::ApiManager$/, '')}::Wrapper::#{api_wrapper.to_s.upcase.gsub(/[^A-Z0-9]/,'_')}"
          # Try constantizing it.
          _module = api_wrapper._constantize rescue nil
          # Complain if the requested wrapper was not found.
          fail Error.new("Wrapper not found #{api_wrapper}") if !_module && raise_if_not_exist
        else
          _module = api_wrapper
        end
        # Exit if there is no wrapper or it is already in use
        return false if !_module || _extended?(_module)
        # Use the wrapper
        extend(_module)
        cloud_api_logger.log("Wrapper: wrapped: #{_module.inspect}.", :wrapper)
        true
      end

    end
  end
end
