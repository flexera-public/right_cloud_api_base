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

    class Error < StandardError
    end

    # Cache hit error
    class CacheHit < Error
    end

    # Cloud specific errors should be raised with this guy
    class CloudError < Error
    end

    # Low level connection errors
    class ConnectionError < CloudError
    end

    class HttpError < CloudError
      attr_reader :code

      def initialize(code, message)
        @code = code.to_s
        super(message)
      end
    end

    class PatternNotFoundError < Error
    end

    class RetryAttempt < Error # :nodoc:
    end

    # The class is the parent class for all the cloud based thread-safe managers.
    #
    # The main purpose of the manager is to check if the current thread or fiber has a thread-unsafe
    # ApiManager instance created or not. If not them the manager creates than instance of ApiManager
    # in the current thread/fiber and feeds the method and parameters to it.
    #
    # @example
    #  
    #  module RightScale
    #    module CloudApi
    #      module MyCoolCloudNamespace
    #        class Manager < CloudApi::Manager
    #        end
    #      end
    #    end
    #  end
    #
    #  # Create an instance of MyCoolCloudNamespace manager.
    #  my_cloud = RightScale::CloudApi::MyCoolCloudNamespace::Manager.new(my_cool_creds)
    #
    #  # Make an API call.
    #  # The call below creates an instance of RightScale::CloudApi::YourCoolCloudNamespace::ApiManager in the
    #  # current thread and invokes "ListMyCoolResources" method on it.
    #  my_cloud.ListMyCoolResources #=> cloud response
    #
    class Manager

      # The initializer.
      # 
      # @param [Any] args Usually a set of credentials.
      #
      # @yield [Any] Optional: the block will be passed to ApiManager on its initialization.
      #
      def initialize(*args, &block)
        @args, @block      = args, block
        options            = args.last.is_a?(Hash) ? args.last : {}
        @api_manager_class = options[:api_manager_class] || self.class.name.sub(/::Manager$/, '::ApiManager')._constantize
        @api_manager_storage = {}
      end

      # Returns the an instance of ApiManager  for the current thread/fiber.
      # The method creates a new ApiManager instance ubless it exist.
      #
      # @return [..::MyCoolCloudNamespace::ApiManager]
      #
      def api_manager
        # Delete dead threads and their managers from the list.
        Utils::remove_dead_fibers_and_threads_from_storage(@api_manager_storage)
        @api_manager_storage[Utils::current_thread_and_fiber] ||= @api_manager_class::new(*@args, &@block)
      end

      # Feeds all unknown methods to the ApiManager instance.
      #
      def method_missing(m, *args, &block)
        api_manager.__send__(m, *args, &block)
      end

    end
  end
end
