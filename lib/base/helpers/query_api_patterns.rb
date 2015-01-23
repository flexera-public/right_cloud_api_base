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

    # Mixins namespace
    #
    # @api public
    #
    module Mixin

      # Query API namespace
      module QueryApiPatterns
        
        # Standard included
        #
        # @return [void]
        # @example
        #   # no example
        #
        def self.included(base)
          base.extend(ClassMethods)
        end


        # Query API patterns help one to simulate the Query API type through the REST API
        #
        # When the REST API is powerfull enough it is not easy to code it becaue one have to worry
        # about the path, the URL parameters, the headers and the body, when in the QUERY API
        # all you need to worry about are the URL parameters.
        #
        # The patterns described below help you to build methods that will take a linear set of
        # parameters (usially) a hash and put then into the proper positions into the URL, headers or
        # body.
        #
        # TODO :add an example that would compare REST vs QUERY calls
        #
        # @example
        #   # Add a QUERY methods pattern:
        #
        #   query_api_pattern 'MethodName', :verb, 'path', UnifiedParams+:params+:headers+:body+:options+:before+:after do |args|
        #     puts   args # where args is a Hash: { :verb, :path, :opts, :manager  }
        #     ...
        #     return args # where args is a Hash: { :verb, :path, :opts [, :manager] }
        #   end
        #
        # There are 2 ways to define a Query API pattern:
        #
        # 1. Manager class level:
        # We could use this when we define a new cloud handler. I dont see any
        # use case right now because we can implement all we need now using the
        # second way and Wrappers.
        #
        # @example
        #   module MyCoolCloud
        #     class  ApiManager < CloudApi::ApiManager
        #       query_api_pattern 'ListBuckets', :get
        #
        #       query_api_pattern 'PutObject',   :put, '{:Bucket}/{:Object}',
        #                                        :body    => Utils::MUST_BE_SET,
        #                                        :headers => { 'content-type' => ['binary/octet-stream'] }
        #       ..
        #     end
        #   end
        #
        # 2. Manager instance level: this is where Wrappers come.
        #
        # @example
        #  module MyCoolCloud
        #    module API_DEFAULT
        #      def self.extended(base)
        #        base.query_api_pattern 'ListBuckets',      :get
        #
        #        base.query_api_pattern 'ListMyCoolBucket', :get do |args|
        #          args[:path] = 'my-cool-bucket'
        #          args
        #        end
        #
        #        base.query_api_pattern 'PutObject',   :put, '{:Bucket:}/{:Object:}',
        #                                              :body    => Utils::MUST_BE_SET,
        #                                              :headers => { 'content-type' => ['binary/octet-stream'] }
        #
        #        base.query_api_pattern 'UploadPartCopy', :put,'{:DestinationBucket}/{:DestinationObject}',
        #                                                 :params  => { 'partNumber' => :PartNumber, 'uploadId'   => :UploadId },
        #                                                 :headers => { 'x-amz-copy-source' => '{:SourceBucket}/{:SourceObject}' }
        #        ..
        #      end
        #    end
        #  end
        #
        # @example
        #   Use case examples:
        #   s3.MethodName(UnifiedParams+:params+:headers+:body+:options+:path+:verb)
        #
        # @example
        #   # List all buckets
        #   s3.ListBuckets
        #
        # @example
        #   # Put object binary
        #   s3.PutObject({'Bucket' => 'xxx', 'Object => 'yyy'}, :body => 'Hahaha')
        #
        # @example
        #   # UploadCopy
        #   s3.UploadPartCopy( 'SourceBucket'      => 'xxx',
        #                      'SourceObject       => 'yyy',
        #                      'DestinationBucket' => 'aaa',
        #                      'DestinationObject' => 'bbb',
        #                      'PartNumber'        => 134,
        #                      'UploadId'          => '111111',
        #                      'foo_param'         => 'foo',
        #                      'bar_param'         => 'bar' )
        #
        module ClassMethods

          # The method returns a list of pattternd defined in the current class
          #
          # @return [Array] The arrays of patterns.
          # @example
          #   # no example
          #
          def query_api_patterns
            @query_api_patterns ||= {}
          end


          # Defines a new query pattern
          #
          # @param [String] method_name The name of the new QUERY-like method;
          # @param [String] verb        The HTTP verb.
          # @param [String] path        The path pattern.
          # @param [Hash]   opts        A set of extra parameters.
          # @option opts [Hash] :params  Url parameters pattern.
          # @option opts [Hash] :headers HTTP headers pattern.
          # @option opts [Hash] :body    HTTP request body pattern.
          # @option opts [Proc] :before  Before callback.
          # @option opts [Hash] :after   After callback.
          # @option opts [Hash] :defaults A set of default variables.
          # @option opts [Hash] :options A set of extra options.
          #
          # TODO: :explain options, callbacks, etc
          #
          # @return [void]
          # @example
          #   # no example
          #
          def query_api_pattern(method_name, verb, path='', opts={}, storage=nil, &block)
            opts        = opts.dup
            method_name = method_name.to_s
            storage   ||= query_api_patterns
            before   = opts.delete(:before)
            after    = opts.delete(:after)    || block
            defaults = opts.delete(:defaults) || {}
            params   = opts.delete(:params)   || {}
            headers  = opts.delete(:headers)  || {}
            options  = opts.delete(:options)  || {}
            body     = opts.delete(:body)     || nil
            # Complain if there are any unused keys left.
            fail(Error.new("#{method_name.inspect} pattern: unsupported key(s): #{opts.keys.map{|k| k.inspect}.join(',')}")) if opts.any?
            # Store the new pattern.
            storage[method_name] = {
              :verb     => verb.to_s.downcase.to_sym,
              :path     => path.to_s,
              :before   => before,
              :after    => after,
              :defaults => defaults,
              :params   => params,
              :headers  => HTTPHeaders::new(headers),
              :options  => options,
              :body     => body }
          end
        end


        # Returns the list of current patterns
        #
        # The patterns can be defined at the class levels or/and in special Wrapper modules.
        # The patterns defined at the class levels are always inherited by the instances of this
        # class, when the wrapper defined patterns are applied to this particular object only.
        #
        # This allows one to define generic patterns at the class level and somehow specific
        # at the level of wrappers.
        #
        # @return [Array] The has of QUERY-like method patterns.
        # @example
        #   # no example
        #
        # P.S. The method is usually called in Wrapper modules (see S3 default wrapper)
        #
        def query_api_patterns
          @query_api_patterns ||= {}
          # The current set of patterns may override whatever is defined at the class level.
          self.class.query_api_patterns.merge(@query_api_patterns)
        end


        # Explains the given pattern by name
        #
        # (Displays the pattern definition)
        #
        # @param [String] pattern_name The pattern method name.
        # @return [Stringq]
        #
        # @example
        #   puts open_stack.explain_query_api_pattern('AttachVolume') #=>
        #      AttachVolume: POST 'servers/{:id}/os-volume_attachments'
        #        - body    :  {:volumeAttachment=>{"volumeId"=>:volumeId, "device"=>:device}}
        #
        def explain_query_api_pattern(pattern_name)
          pattern_name = pattern_name.to_s
          result       = "#{pattern_name}: "
          pattern      = query_api_patterns[pattern_name]
          unless pattern
            result << 'does not exist'
          else
            result << "#{pattern[:verb].to_s.upcase} '#{pattern[:path]}'"
            [:params, :headers, :options, :body, :before, :after].each do |key|
              result << ("\n  - %-8s:  #{pattern[key].inspect}" % key.to_s) unless pattern[key]._blank?
            end
          end
          result
        end


        # Set object specific QUERY-like pattern
        #
        # This guy is usually called from Wrapper's module from self.extended method (see S3 default wrapper)
        #
        # @return [void]
        # @example
        #   # no example
        #
        def query_api_pattern(method_name, verb, path='', opts={}, &block)
          self.class.query_api_pattern(method_name, verb, path, opts, @query_api_patterns, &block)
        end


        # Build request based on the given set of variables and QUERY-like api pattern
        #
        # @api private
        #
        # @param [String] query_pattern_name The QUERY-like pattern name.
        # @param [param_type] query_params A set of options.
        #
        # @yield [block_params] block_description
        # @yieldreturn [block_return_type] block_return_description
        #
        # @return [return] return_description
        # @example
        #   # no example
        #
        # @raise [error] raise_description
        #
        def compute_query_api_pattern_based_params(query_pattern_name, query_params={})
          # fix a method name
          pattern = query_api_patterns[query_pattern_name.to_s]
          # Complain if we dont know the method
          raise PatternNotFoundError::new("#{query_pattern_name.inspect} pattern not found") unless pattern
          # Make sure we got what we expected
          query_params ||= {}
          raise Error::new("Params must be Hash but #{query_params.class.name} received.") unless query_params.is_a?(Hash)
          # Make a new Hash instance from the incoming Hash.
          # Do not clone because we don't want to have HashWithIndifferentAccess instance or
          # something similar because we need to have Symbols and Strings separated.
          query_params = Hash[query_params]
          opts           = {}
          opts[:body]    = query_params.delete(:body)
          opts[:headers] = query_params.delete(:headers) || {}
          opts[:options] = query_params.delete(:options) || {}
          opts[:params]  = query_params._stringify_keys
          opts[:manager] = self
          request_opts   = compute_query_api_pattern_request_data(query_pattern_name, pattern, opts)
          # Try to use custom :process_rest_api_request method first because some auth things
          # may be required.
          # (see OpenStack case) otherwise use standard :process_api_request method
          { :method => respond_to?(:process_rest_api_request) ? :process_rest_api_request : :process_api_request,
            :verb   => request_opts.delete(:verb),
            :path   => request_opts.delete(:path),
            :opts   => request_opts }
        end
        private :compute_query_api_pattern_based_params


        # Execute pattered method if it exists
        #
        # @raise [PatternNotFoundError]
        #
        # @return [Object]
        # @example
        #   # no example
        #
        def invoke_query_api_pattern_method(method_name, *args, &block)
          computed_data = compute_query_api_pattern_based_params(method_name, args.first)
          # Make an API call:
          __send__(computed_data[:method],
                   computed_data[:verb],
                   computed_data[:path],
                   computed_data[:opts],
                   &block)
        end


        # Create custom method_missing method
        #
        # If the called method is not explicitly defined then it tries to find the method definition
        # in the QUERY-like patterns. And if the method is there it builds a request based on the
        # pattern definition.
        #
        # @return [Object]
        # @example
        #   # no example
        #
        def method_missing(method_name, *args, &block)
          begin
            invoke_query_api_pattern_method(method_name, *args, &block)
          rescue PatternNotFoundError
            super
          end
        end


        FIND_KEY_REGEXP           = /\{:([a-zA-Z0-9_]+)\}/
        FIND_COLLECTION_1_REGEXP  = /\[\{:([a-zA-Z0-9_]+)\}\]/
        FIND_COLLECTION_2_REGEXP  = /^([^\[]+)\[\]/
        FIND_REPLACEMENT_REGEXP   = /\{:([a-zA-Z0-9_]+)\}(?!\])/
        FIND_BLANK_KEYS_TO_REMOVE = /\{!remove-if-blank\}/


        # Prepares patters params
        #
        # @api private
        #
        # Returns a hash of parameters (:params, :options, :body, :headers, etc) that will
        # used for making an API request.
        #
        # @return [Hash]
        # @example
        #   # no example
        #
        def compute_query_api_pattern_request_data(method_name, pattern, opts={}) # :nodoc:
          container           = opts.dup
          container[:verb]  ||= pattern[:verb]
          container[:path]  ||= pattern[:path]
          container[:error] ||= Error
          [ :params, :headers, :options, :defaults ].each do |key|
            container[key] ||= {}
            container[key]   = (pattern[key] || {}).merge(container[key])
          end
          container[:defaults] = container[:defaults]._stringify_keys
          container[:headers]  = HTTPHeaders::new(container[:headers])
          # Call "before" callback (if it is)
          pattern[:before].call(container) if pattern[:before].is_a?(Proc)
          # Mix default variables into the given set of variables and
          # initialize the list of used variables.
          container[:params_with_defaults] = container[:defaults].merge(container[:params])
          used_params = []
          # Compute: Path, UrlParams,Headers and Body
          compute_query_api_pattern_path(method_name, container, used_params)
          compute_query_api_pattern_headers(method_name, container, used_params)
          compute_query_api_pattern_body(method_name, container, used_params, pattern)
          compute_query_api_pattern_params(method_name, container, used_params)
          # Delete used query params. The params that are left will go into URL params set later.
          used_params.each do |key| 
            container[:params].delete(key.to_s)
            container[:params].delete(key.to_sym)
          end
          container.delete(:params_with_defaults)
          # Call "after" callback (if it is)
          pattern[:after].call(container) if pattern[:after].is_a?(Proc)
          # Remove temporary variables.
          container.delete(:error)
          container.delete(:manager)
          #
          container
        end
        private :compute_query_api_pattern_request_data


        # Computes the path for the API request
        #
        # @api private
        #
        # @param [String] query_api_method_name Auery API like pattern name.
        # @param [Hash] container The container for final parameters.
        # @param [Hash] used_query_params The list of used variables.
        #
        # @return [String] The path.
        # @example
        #   # no example
        #
        def compute_query_api_pattern_path(query_api_method_name, container, used_query_params)
          container[:path] = compute_query_api_pattern_param(query_api_method_name, container[:path], container[:params_with_defaults], used_query_params)
        end
        private :compute_query_api_pattern_path


        # Computes the set of URL params for the API request
        #
        # @api private
        #
        # @param [String] query_api_method_name Auery API like pattern name.
        # @param [Hash] container The container for final parameters.
        # @param [Hash] used_query_params The list of used variables.
        #
        # @return [Hash] The set of URL params.
        # @example
        #   # no example
        #
        def compute_query_api_pattern_params(query_api_method_name, container, used_query_params)
          container[:params] = compute_query_api_pattern_param(query_api_method_name, container[:params], container[:params_with_defaults],  used_query_params)
        end
        private :compute_query_api_pattern_params


        # Computes the set of headers for the API request
        #
        # @api private
        #
        # @param [String] query_api_method_name Auery API like pattern name.
        # @param [Hash] container The container for final parameters.
        # @param [Hash] used_query_params The list of used variables.
        #
        # @return [Hash] The set of HTTP headers.
        # @example
        #   # no example
        #
        def compute_query_api_pattern_headers(query_api_method_name, container, used_query_params)
          container[:headers].dup.each do |header, header_values|
            container[:headers][header].each_with_index do |header_value, idx|
              container[:headers][header] = container[:headers][header].dup
              container[:headers][header][idx] = compute_query_api_pattern_param(query_api_method_name, header_value, container[:params_with_defaults],  used_query_params)
              container[:headers][header].delete_at(idx) if container[:headers][header][idx] == Utils::NONE
            end
          end
        end
        private :compute_query_api_pattern_headers


        # Computes the body value for the API request
        #
        # @api private
        #
        # @param [String] query_api_method_name Auery API like pattern name.
        # @param [Hash] container The container for final parameters.
        # @param [Hash] used_query_params The list of used variables.
        # @param [Hash] pattern The pattern.
        #
        # @return [Hash,String] The HTTP request body..
        # @example
        #   # no example
        #
        def compute_query_api_pattern_body(query_api_method_name, container, used_query_params, pattern)
          if container[:body].nil? && !pattern[:body].nil?
            # Make sure body is not left blank when it must be set
            fail(Error::new("#{query_api_method_name}: body parameter must be set")) if pattern[:body] == Utils::MUST_BE_SET
            container[:body] = compute_query_api_pattern_param(query_api_method_name, pattern[:body], container[:params_with_defaults], used_query_params)
          end
        end
        private :compute_query_api_pattern_body


        # Computes single Query API pattern parameter
        #
        # @param [String] query_api_method_name Auery API like pattern name.
        # @param [Hash] source The param to compute/parse.
        # @param [Hash] used_query_params The list of used variables.
        # @param [Hash] params_with_defaults The set of parameters passed by a user + all the default
        #   values defined in wrappers.
        # 
        # @return [Object]
        # @example
        #   # no example
        #
        def compute_query_api_pattern_param(query_api_method_name, source, params_with_defaults, used_query_params) # :nodoc:
          case
          when source.is_a?(Hash)   then compute_query_api_pattern_hash_data(query_api_method_name, source, params_with_defaults, used_query_params)
          when source.is_a?(Array)  then compute_query_api_pattern_array_data(query_api_method_name, source, params_with_defaults, used_query_params)
          when source.is_a?(Symbol) then compute_query_api_pattern_symbol_data(query_api_method_name, source, params_with_defaults, used_query_params)
          when source.is_a?(String) then compute_query_api_pattern_string_data(query_api_method_name, source, params_with_defaults, used_query_params)
          else                           source
          end
        end


        #-----------------------------------------
        # Query API pattents: HASH
        #-----------------------------------------

        # Parses Query API replacements
        #
        # @api private
        #
        # You may define a key so that is has a default value but you may override it if you 
        # provide another "replacement" key.
        # 
        # The replacement key is defined as "KeyToSentToCloud{:ReplacementKeyName}" string and
        # it will send 'KeyToSentToCloud' with the value taken from 'ReplacementKeyName' if
        # 'ReplacementKeyName' is provided.
        #
        # @param [Hash] params_with_defaults A set API call parameters.
        # @param [Array] used_params An array that lists all the paramaters names who were already
        #   somehow used for this api call. All the unused params wil go into URL params
        # @param [String] key The current key.
        # @param [Object] value The current value,
        # @param [Hash] result The resulting hash that has all the transformed params.
        #
        # @return [Array] The updated key name and its value
        #
        # @example:
        #   # Example 1: simple case.
        #   query_api_pattern 'CreateServer', :post, 'servers',
        #     :body => {
        #       Something{:Replacemet} => {'X' => 1, 'Y' => 2}
        #     }
        #
        #   # 1.a
        #   api.CreateServer #=>
        #     # it will set request body to:
        #     #  { Something => {'X' => 1, 'Y' => 2} }
        #
        #   # 1.b
        #   api.CreateServer('Replacement' => 'hahaha' ) #=>
        #     # it will set request body to:
        #     #  { Something => 'hahaha' }
        #
        #   # Example 2: complex case:
        #   query_api_pattern :MyApiCallName, :get, '',
        #     :body    => {
        #       'Key1' => :Value1,
        #       'Collections{:Replacement}' => {    # <-- The key with Replacement
        #         'Collection[{:Items}]' => {
        #           'Name'  => :Name,
        #           'Value' => :Value
        #         }
        #       }
        #      },
        #     :defaults => {
        #       :Key1 => 'hoho',
        #       :Collections => Utils::NONE
        #     }
        #
        #   # 2.a No parameters are provided
        #   api.MyApiCallName #=>
        #     # it will set request body to:
        #     #  { 'Key1' => 'hoho' }
        #
        #   # 2.b Some parameters are provided:
        #   api.MyApiCallName('Key1' => 'woohoo', 'Items' => [ {'Name' => 'a', 'Value' => 'b'},
        #     {'Name' => 'b', 'Value' => 'c'}  ]) #=>
        #     # it will set request body to:
        #     #   { 'Key1' => 'woohoo',
        #     #     'Collections' =>
        #     #       {'Collection' =>
        #     #         [ {'Name' => 'a', 'Value' => 'b'},
        #     #           {'Name' => 'c', 'Value' => 'd'} ] } }
        #     #
        #
        #   # 2.c Areplacement key is provided:
        #   api.MyApiCallName('Key1' => 'ahaha', 'Replacement' => 'oooops') #=>
        #     # it will set request body to:
        #     #  { 'Key1' => 'ahaha',
        #          'Collections' => 'oooops' }
        #
        def parse_query_api_pattern_replacements(params_with_defaults, used_params, key, value, result)
          # Test the current key if it has a replacement mark or not.
          # If not then we do nothing.
          replacement_key = key[FIND_REPLACEMENT_REGEXP] && $1
          if replacement_key
            # If it is a key with a possible replacement then we should exract the replacement
            # variable name from the key:
            # so that 'CloudKeyName{:ReplacementKeyName}' should transform into:
            # key -> 'CloudKeyName' and replacement_key -> 'ReplacementKeyName'.
            #
            result.delete(key)
            key = key.sub(FIND_REPLACEMENT_REGEXP, '')
            if params_with_defaults.has_key?(replacement_key)
              # If We have 'ReplacementKeyName' passed by a user or set by default then we should use
              # its value otherwise we keep the original value that was defined for 'CloudKeyName'.
              #
              # Anyway the final key name is 'CloudKeyName'.
              #
              value = params_with_defaults[replacement_key]
              used_params << replacement_key
            end
          end
          [key, value]
        end
        private :parse_query_api_pattern_replacements


        # Collections
        #
        # @api private
        #
        # The simple definition delow tells us that parameters will have a key named "CloudKeyName"
        # which will point to an Array of Hashes. Where every hash will have keys: 'Key' and 'Value'
        #
        # @param [String] method_name The name of the pattern.
        # @param [Hash] params_with_defaults A set API call parameters.
        # @param [Array] used_params An array that lists all the paramaters names who were already
        #   somehow used for this api call. All the unused params wil go into URL params
        # @param [String] key The current key.
        # @param [Object] value The current value,
        # @param [Hash] result The resulting hash that has all the transformed params.
        #
        # @return [Array] The updated key name and its value
        #
        # @raise [Error] If things go wrong in the method.
        #
        # @example
        #  # Example 1: Simple Collection definition:
        #
        #   query_api_pattern :MyApiCallName, :get, '',
        #     :body    => {
        #       'CloudKeyName[]' => {
        #         'Name'  => :Key,
        #         'State' => :Value
        #       }
        #      }
        #
        #   api.MyApiCallName('CloudKeyName' => [{'Key' => 1, 'Value' => 2},
        #                                       {'Key' => 3, 'Value' => 4}]) #=>
        #     # it will set request body to:
        #     #   'CloudKeyName' => [
        #     #     {'Name' => 1, 'State' => 2},
        #     #     {'Name' => 3, 'State' => 4} ]
        #
        # The collection may comsume values from a parameter that has name differet from the
        # 'CloudKeyName' in the example above:
        #
        # @example
        #  # Example 2: Simple Collection definition:
        #
        #   query_api_pattern :MyApiCallName, :get, '',
        #     :body    => {
        #       'CloudKeyName[{:Something}]' => {
        #         'Name'  => :Key,
        #         'State' => :Value
        #       }
        #      }
        #
        #   api.MyApiCallName('Something' => [{'Key' => 1, 'Value' => 2},
        #                                     {'Key' => 3, 'Value' => 4}]) #=>
        #     # it will set request body to the same value as above:
        #     #   'CloudKeyName' => [
        #     #     {'Name' => 1, 'State' => 2},
        #     #     {'Name' => 3, 'State' => 4} ]
        #
        # You can nest the collections:
        #
        # @example
        #   query_api_pattern :MyApiCallName, :get, '',
        #     :body    => {
        #       'CloudKeyName[]' => {
        #         'Name'     => :Key,
        #         'States[]' => {
        #           'SubState' => :SubKey,
        #           'FixedKey' => 13
        #         }
        #       }
        #      }
        #
        #   api.MyApiCallName('CloudKeyName' => [{'Key' => 1,
        #                                         'States' => [{'SubState' => 'x'},
        #                                                      {'SubState' => 'y'},
        #                                                      {'SubState' => 'y'}]},
        #                                        {'Key' => 3,
        #                                         'States' => {'SubState' => 'a'}}])
        #
        # If a collection was defined with the default value == Utils::NONE it will remove
        # the collection key from the final hash of params unless any collection items were passed.
        #
        #   query_api_pattern :MyApiCallName, :get, '',
        #     :body    => {
        #       'CloudKeyName[]' => {
        #         'Name'  => :Key,
        #         'State' => :Value
        #       }
        #      },
        #    :defaults => Utils::NONE
        #
        #   api.MyApiCallName() #=>
        #     # it will set request body to: {}
        #
        def parse_query_api_pattern_collections(method_name, params_with_defaults, used_params, key, value, result)
          # Parse complex collection: KeyName[{:VarName}]'
          collection_key   = key[FIND_COLLECTION_1_REGEXP] && $1
          # Parse simple collection: KeyName[]'
          collection_key ||= key[FIND_COLLECTION_2_REGEXP] && $1
          # Do nothing unless there is a collection key detected
          if collection_key
            # Delete the original key from the resulting hash because it has collection crap in it.
            sub_pattern = result.delete(key)
            # Extract the real key from the original mixed collection key.
            # in the case of:
            # - 'KeyName[{:VarName}]' the real key is 'KeyName' and the collection key is 'VarName';
            # - 'KeyName[]' the real key and the collection key are both 'KeyName'.
            key = key[/^[^\[]*/]
            # If a user did not pass collection key and the key has not been given a default value
            # when the current pattern was defined we should fail.
            fail Error::new("#{method_name}: #{collection_key.inspect} is required") unless params_with_defaults.has_key?(collection_key)
            # Grab the values for the collection from what the user sent of from the default defs.
            value = params_with_defaults[collection_key]
            # Walk through all the collection items and substitule required values into it.
            if value.is_a?(Array) || value.is_a?(Hash)
              value = value.dup
              value = [ value ] if value.is_a?(Hash)
              value.each_with_index do |item_params, idx|
                # The values given by the user (or the default ones) must be defined as hashes.
                fail Error::new("#{method_name}: Collection items must be Hash instances but #{item_params.inspect} is provided") unless item_params.is_a?(Hash)
                # Recursively pdate them all.
                value[idx] = compute_query_api_pattern_param(method_name, sub_pattern, params_with_defaults.merge(item_params), used_params)
              end
            end
            # Mark the collection key as the one that has been used already.
            used_params << collection_key
          else
            value = compute_query_api_pattern_param(method_name, value, params_with_defaults, used_params) unless value == Utils::NONE
          end
          value == Utils::NONE ? result.delete(key) : result[key] = value
          [key, value]
        end
        private :parse_query_api_pattern_collections


        # Deals with blank values.
        #
        # @api private
        #
        # If the given key responds to "blank? and it is true and it is marked as to be removed if
        # it is blank then we remove it in this method.
        #
        # @param [String] key The current key.
        # @param [Object] value The current value,
        # @param [Hash] result The resulting hash that has all the transformed params.
        #
        # @return [Array] The updated key name and its value.
        #
        def parse_query_api_pattern_remove_blank_key( key, value, result)
          # 'KeyName{!remove-if-blank}'
          blank_key_sign = key[FIND_BLANK_KEYS_TO_REMOVE]
          if blank_key_sign
            # Delete the original key from the resulting hash.
            result.delete(key)
            # But if its value is not blank then fix the key name (get rid of {!remove-if-blank}) and
            # put it back.
            unless value.respond_to?(:_blank?) && value._blank?
              key = key.sub(blank_key_sign, '')
              result[key] = value
            end
          end
          [key, value]
        end
        private :parse_query_api_pattern_remove_blank_key


        # Parses Hash objects
        #
        # @api private
        #
        # @return [Hash]
        #
        def compute_query_api_pattern_hash_data(method_name, source, params_with_defaults, used_params)
          result = source.dup
          source.dup.each do |key, value|
            # Make sure key is a String
            key = key.to_s.dup
            # Subsets replacement
            key, value = *parse_query_api_pattern_replacements(params_with_defaults, used_params, key, value, result)
            # Collections replacement
            key, value = *parse_query_api_pattern_collections(method_name, params_with_defaults, used_params, key, value, result)
            # Remove empty keys
            parse_query_api_pattern_remove_blank_key(key, value, result)
          end
          result
        end
        private :compute_query_api_pattern_hash_data


        #-----------------------------------------
        # Query API pattern: ARRAY
        #-----------------------------------------

        # Parses Array objects
        #
        # @return [Array]
        #
        def compute_query_api_pattern_array_data(query_api_method_name, source, params_with_defaults, used_query_params)
          result = source.dup
          source.dup.each_with_index do |item, idx|
            value = compute_query_api_pattern_param(query_api_method_name, item, params_with_defaults, used_query_params)
            value == Utils::NONE ? result.delete_at(idx) : result[idx] = value
          end
          result
        end


        #-----------------------------------------
        # Query API pattern: STRING
        #-----------------------------------------

        # Parses String objects
        #
        # @return [String]
        #
        # @raise [Error]
        #
        def compute_query_api_pattern_string_data(query_api_method_name, source, params_with_defaults, used_query_params)
          result = source.dup
          result.scan(FIND_KEY_REGEXP).flatten.each do |key|
            fail Error::new("#{query_api_method_name}: #{key.inspect} is required") unless params_with_defaults.has_key?(key)
            value = params_with_defaults[key]
            result.gsub!("{:#{key}}", value == Utils::NONE ? '' : value.to_s)
            used_query_params << key
          end
          result
        end


        #-----------------------------------------
        # Query API pattern: SYMBOL
        #-----------------------------------------

        # Parses Symbol objects
        #
        # @return [String]
        #
        # @raise [Error]
        #
        def compute_query_api_pattern_symbol_data(query_api_method_name, source, params_with_defaults, used_query_params)
          key = source.to_s
          fail Error::new("#{query_api_method_name}: #{key.inspect} is required") unless params_with_defaults.has_key?(key)
          result = params_with_defaults[key]
          used_query_params << key
          result
        end

      end
    end
  end
end
