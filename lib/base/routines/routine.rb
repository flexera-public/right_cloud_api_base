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

    # This is a parent class for all the other routines.
    #
    # The routine is a very simple object that does a simple task in the API call processing stack
    # and exits. In most cases a single routine knows nothing about any other routines. It just
    # takes incoming params from @data hash, processes it and stores back to the @adata attribute.
    #
    class Routine
      attr_reader :data

      # Initializes the @data attribute. Is called before *process* method.
      #
      # @param [Hash] data See ApiManager for better explanation what data is.
      #
      def reset(data=nil)
        @data = data
      end

      # Main entry point. The method must be overriden by sub-classes.
      def process
        raise Error::new("This method should be implemented by a subclass")
      end

      # Initialize and process the routine. Is usially called from unit tests.
      def execute(data)
        reset(data)
        process
      end

      # Current options.
      #
      # @return [Hash]
      #
      def options
        @data[:options]
      end

      # Current logger.
      #
      # @return [CloudApiLogger]
      #
      def cloud_api_logger
        options[:cloud_api_logger]
      end

      # The method takes a block of code and logs how much time the given block took to execute.
      #
      # @param [String] description The prefix that is added to every logged line.
      # @param [Symbol] log_key The log key (see {RightScale::CloudApi::CloudApiLogger}).
      #
      def with_timer(description = 'Timer', log_key = :timer, &block)
        cloud_api_logger.log("#{description} started...",:timer)
        start  = Time::now
        result = block.call
        cloud_api_logger.log("#{description} completed (#{'%.6f' % (Time::now - start)} sec)", log_key)
        result
      end
      
      # A helper method for invoking callbacks.
      #
      # The method checks if the given Proc exists and invokes it with the given set of arguments.
      # In the case when proc==nil the method does nothing.
      #
      # @param [Proc] proc The callback.
      # @param [Any] args A set of callback method arguments.
      #
      def invoke_callback_method(proc, *args) # :nodoc:
        proc.call(*args) if proc.is_a?(Proc)
      end
    end
    
  end
end