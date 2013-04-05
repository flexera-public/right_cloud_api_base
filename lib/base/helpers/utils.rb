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

    class BlankSlate
      instance_methods.each { |m| undef_method m unless m =~ /(^__)|(^object_id$)/ }
    end

    module Utils

      ONE_DAY_OF_SECONDS = 60*60*24
      MUST_BE_SET      = :__MUST_BE_SET__
      NONE             = :__NONE__

      # URL encodes a string.
      #
      # @param [String] str A string to escape.
      #
      # @return [String] The escaped string.
      #
      # P.S. URI.escape is deprecated in ruby 1.9.2+
      #
      def self.url_encode(str)
        CGI::escape(str.to_s).gsub("+", "%20")
      end

      def self.base64en(string)
        Base64::encode64(string.to_s).strip
      end
      
      # Makes a URL params string from a given hash. If block is given the it invokes the block on
      # every value so that one could escape it in his own way. If there is no block it url_encode
      # values automatically.
      #
      # @param [Hash] params A set of URL params => values.
      #
      # @yield [String] Current value.
      # @yieldreturn [String] The escaped value.
      #
      # @return [String] The result.
      #
      # @example
      #  RightScale::CloudApi::Utils::params_to_urn(
      #   "InstanceId.1" => 'i-12345678',
      #   "InstanceName" => "",
      #   "Reboot"       => nil,
      #   "XLogPath"     => "/mypath/log file.txt") #=> "InstanceId.1=i-12345678&InstanceName=&Reboot&XLogPath=%2Fmypath%2Flog%20with%20spaces.txt"
      #
      # Block can be used to url encode keys and values:
      #
      # @example
      #  RightScale::CloudApi::Utils::params_to_urn(
      #    "InstanceId.1" => 'i-12345678',
      #    "InstanceName" => "",
      #    "Reboot"       => nil,
      #    "XLogPath"     => "/mypath/log with spaces.txt") do |value|
      #    RightScale::CloudApi::AWS::Utils::amz_escape(value) #=> "InstanceId.1=i-12345678&InstanceName=&Reboot&XLogPath=%2Fmypath%2Flog%20with%20spaces.txt"
      #  end
      #
      # P.S. Nil values are interpreted as valuesless ones and "" are as blank values
      #
      def self.params_to_urn(params={}, &block)
        block ||= Proc::new { |value| url_encode(value) }
        params.keys.sort.map do |name|
          value, name = params[name], block.call(name)
          value.nil? ? name : [value].flatten.inject([]) { |m, v| m << "#{name}=#{block.call(v)}"; m }.join('&')
        end.compact.join('&')
      end

      # Joins pathes and URN params into a well formed URN.
      # Block can be used to url encode URN param's keys and values.
      #
      # @param [String] absolute Absolute path.
      # @param [Array] relatives Relative pathes (Strings) and URL params (Hash) as a very last item.
      #
      # @yield [String] Current URL param value.
      # @yieldreturn [String] The escaped URL param value.
      #
      # @example
      #  join_urn(absolute, [relative1, [..., [relativeN, [urn_params, [&block]]]]])
      #
      # @example
      #  RightScale::CloudApi::Utils::join_urn(
      #    "service/v1.0",
      #    "servers/index",
      #    "blah-bllah",
      #    "InstanceId.1" => 'i-12345678',
      #    "InstanceName" => "",
      #    "Reboot"       => nil,
      #    "XLogPath"     => "/mypath/log with spaces.txt") #=>
      #      "/service/v1.0/servers/index/blah-bllah?InstanceId.1=i-12345678&InstanceName=&Reboot&XLogPath=%2Fmypath%2Flog%20with%20spaces.txt"
      #
      def self.join_urn(absolute, *relatives, &block)
        # Fix absolute path
        absolute = absolute.to_s
        result   = absolute[/^\//] ? absolute.dup : "/#{absolute}"
        # Extract urn_params if they are
        urn_params = relatives.last.is_a?(Hash) ? relatives.pop : {}
        # Add relative pathes
        relatives.each do |relative|
          relative = relative.to_s
          # skip relative path if is blank
          next if relative._blank?
          # KD: small hack if relative starts with '/' it should override everything before and become a absolute path
          if relative[/^\//]
            result = relative
          else
            result << (result[/\/$/] ? relative : "/#{relative}")
          end
        end
        # Add there a list of params
        urn_params = params_to_urn(urn_params, &block)
        urn_params._blank? ? result : "#{result}?#{urn_params}"
      end

      # Get a hash of URL parameters from URL string.
      #
      # @param [String] url The URL.
      #
      # @return [Hash] A hash with parameters parsed from the URL.
      #
      # @example
      #  parse_url_params('https://ec2.amazonaws.com/?w=1&x=3&y&z') #=> {"z"=>nil, "y"=>nil, "x"=>"3", "w"=>"1"}
      #
      # @example
      #  parse_url_params('https://ec2.amazonaws.com') #=> {}
      #
      def self.extract_url_params(url)
        URI::parse(url).query.to_s.split('&').map{|i| i.split('=')}.inject({}){|result, i| result[i[0]] = i[1]; result  }
      end

      #-------------------------------------------------------------------------
      # Other Patterns
      #-------------------------------------------------------------------------

      # Checks if a response/request data matches to the pattern
      # Returns true | nil
      #
      #  Pattern is a Hash:
      #    :verb      => Condition, # HTTP verb: get|post|put etc
      #    :path      => Condition, # Request path must match Condition
      #    :request   => Condition, # Request body must match Condition
      #    :code      => Condition, # Response code must match Condition
      #    :response  => Condition, # Response body must match Condition
      #    :path!     => Condition, # Request path must not match Condition
      #    :request!  => Condition, # Request body must not match Condition
      #    :code!     => Condition, # Response code must not match Condition
      #    :response! => Condition, # Response body must not match Condition
      #    :if        => Proc::new{ |opts| do something } # Extra condition: should return true | false
      #  
      #   (Condition above is /RegExp/ or String or Symbol) 
      #   
      #  Opts is a Hash:
      #    :request  => Object, # HTTP request instance
      #    :response => Object, # HTTP response instance
      #    :verb     => String, # HTTP verb
      #    :params   => Hash,   # Initial request params Hash
      #
      def self.pattern_matches?(pattern, opts={})
        request, response, verb = opts[:request], opts[:response], opts[:verb].to_s.downcase
        mapping = { :verb      => verb,
                    :path      => request.path,
                    :request   => request.body,
                    :code      => response && response.code,
                    :response  => response && response.body }
        # Should not match cases (return immediatelly if any of the conditions matches)
        mapping.each do |key, value|
          key = "#{key}!".to_sym   # Make key negative
          condition = pattern[key]
          next unless condition 
          return nil if case 
                        when condition.is_a?(Regexp) then value[condition]
                        when condition.is_a?(Proc)   then condition.call(value)
                        else condition.to_s.downcase == value.to_s.downcase
                        end
        end
        # Should match cases (return immediatelly if any of the conditions does not match)
        mapping.each do |key, value|
          condition = pattern[key]
          next unless condition 
          return nil unless case 
                            when condition.is_a?(Regexp) then value[condition]
                            when condition.is_a?(Proc)   then condition.call(value)
                            else condition.to_s.downcase == value.to_s.downcase
                            end
        end
        # Should also match 
        return nil if pattern[:if] && !pattern[:if].call(opts)
        true
      end
      
      # Returns an Array with the current Thread and Fiber (if exists) instances.
      #
      # @return [Array] The first item is the current Thread instance and the second item
      #   is the current Fiber instance. For ruby 1.8.7 may return only the first item.
      #
      def self::current_thread_and_fiber
        if defined?(::Fiber) && ::Fiber::respond_to?(:current)
          [ Thread::current, Fiber::current ]
        else
          [ Thread::current ]
        end
      end

      # Storage is an Hash: [Thread, Fiber|nil] => something
      def self::remove_dead_fibers_and_threads_from_storage(storage)
        storage.keys.each do |thread_and_fiber|
          thread, fiber = *thread_and_fiber
          unless (thread.alive? && (!fiber || (fiber && fiber.alive?)))
            storage.delete(thread_and_fiber)
          end
        end
      end
      
      # Transforms body (when it is a Hash) into String
      #
      # @param [Hash] body The request body as a Hash instance.
      # @param [String] content_type The required content type ( only XML and JSON formats are supported).
      #
      # @return [String] The body as a String.
      #
      # @raise [RightScale::CloudApi::Error] When the content_type is not supported
      #
      # @example
      #   RightScale::CloudApi::Utils.contentify_body(@body,'json') #=>
      #     '{"1":"2"}'
      #
      # @example
      #   RightScale::CloudApi::Utils.contentify_body(@body,'xml') #=>
      #     "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<1>2</1>"
      #
      def self.contentify_body(body, content_type)
        return body unless body.is_a?(Hash)
        # Transform
        case dearrayify(content_type).to_s
        when /json/ then body.to_json
        when /xml/  then body._to_xml!
        else fail        Error::new("Can't transform body from Hash into #{content_type.inspect} type String")
        end
      end
      
      # Generates a unique token (Uses UUID when possible)
      #
      # @return [String] A random 28-symbols string.
      #
      # @example
      #  Utils::generate_token => "1f4a91d7-3650-7b22-f401-6f9c54bcf5e5"  # if UUID
      #
      # @example
      #  Utils::generate_token => "062e32337633070448fd0d284c46c2b9a41b"  # otherwise
      #
      def self.generate_token
        # Use UUID gem if it is
        if defined?(UUID) && UUID::respond_to?(:new)
          uuid = UUID::new
          return uuid.generate if uuid.respond_to?(:generate)          
        end
        # Otherwise generate a random token
        time   = Time::now.utc
        token  = "%.2x"  % (time.to_i % 256 )
        token << "%.6x" % ((rand(256)*1000000 + time.usec) % 16777216 )
        # [4, 4, 4, 12].each{ |count| token << "-#{random(count)}" } # UUID like
        token << random(28)
        token
      end

      # Generates a random sequence.
      #
      # @param [Integer] size The length of the random string.
      # @param [Hash] options A set of options
      # @option options [Integer] :base (is 16 by default to generate HEX output)
      # @option options [Integer] :offset (is 0 by default)
      #
      # @return [String] A random string.
      #
      # @example
      #  Utils::random(28) #=> "d8b2292c8de43256b6eaf91129d3"  # (0-9 + a-f)
      #
      # @example
      #  Utils::random(28, :base => 26, :offset => 10) #=> "jaunwhhdameatxilyavsnnnwpets"  # (a-z)
      #
      # @example
      #  Utils::random(28, :base => 10) #=> "4330946481889419283880628515"  # (0-9)
      #
      def self.random(size=1, options={})
        options[:base]   ||= 16
        options[:offset] ||= 0
        result = ''
        size.times{ result << (rand(options[:base]) + options[:offset]).to_s(options[:base] + options[:offset]) }
        result
      end

      # Arrayifies the given object unless it is an Array already.
      #
      # @param [Object] object Any possible object.
      #
      # @return [Array] It wraps the given object into Array.
      #
      def self.arrayify(object)
        object.is_a?(Array) ? object : [ object ]
      end

      # De-Arrayifies the given object.
      #
      # @param [Object] object Any possible object.
      #
      # @return [Object] If the object is not an Array instance it just returns the object.
      #   But if it is an Array the method returns the first element of the array.
      #
      def self.dearrayify(object)
        object.is_a?(Array) ? object.first : object
      end

      # Returns an XML parser by its string name.
      # If the name is empty it returns the default parser (Parser::Sax).
      #
      # @param [String] xml_parser_name The name of the parser ('sax' or 'rexml').
      #
      # @return [Class] The parser class
      #
      # @raise [RightScale::CloudApi::Error] When an unexpected name is passed.
      #
      def self.get_xml_parser_class(xml_parser_name)
        case xml_parser_name.to_s.strip
        when 'sax',''  then Parser::Sax    # the default one
        when 'rexml'   then Parser::ReXml
        else                fail Error::new("Unknown parser: #{xml_parser_name.inspect}")
        end
      end

      # Get attribute value(s) or try to inherit it from superclasses.
      #
      # @param [Class] klass The source class.
      # @param [String,Symbol] attribute The name of the attribute reader.
      # @param [Array] values Some extra data to be returned with the calculated results.
      #
      # @return [Array] An array of values in the next formt:
      #   [ ..., SuperSuperClass.attribute, ..., self.attribute, values[0], ..., values[last]]
      #
      # @yield [Any] The block is called with "current attribute" so the block can modify it.
      # @yieldreturn [Any] When block is passed then it should return a "modified" attribute.
      #
      def self.inheritance_chain(klass, attribute, *values, &block) # :nodoc:
        chain, origin = [], klass
        while origin.respond_to?(attribute) do
          values.unshift(origin.__send__(attribute))
          origin = origin.superclass
        end
        values.each do |value|
          value = block ? block.call(value) : value
          chain << value if value
        end
        chain
      end
      
    end
  end
end
