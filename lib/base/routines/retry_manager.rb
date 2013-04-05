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

    # The routine is responsible for retries/reiterations.
    #
    # If retries are enabled then a singe API call may perform upto DEFAULT_RETRY_COUNT request
    # attempts who may take upto DEFAULT_REITERATION_TIME secsons.
    #
    class RetryManager < Routine
      class Error < CloudApi::Error
      end
      
      DEFAULT_RETRY_COUNT      =   2
      DEFAULT_REITERATION_TIME =  10
      DEFAULT_SLEEP_TIME       = 0.2
      
      # Retries manager.
      # 
      # The manager usually takes the very first position in routins chain.
      # It just increments its counters if we did not reach a possible count of retries or
      # complains if there are no attempts left or if API request time is over.
      #
      # There are 2 possible resons for a retry to be performed:
      #  1. There was a redirect request (HTTP 3xx code)
      #  2. There was an error (HTTP 5xx, 4xx) and
      #
      def process
        retry_options    = data[:options][:retry]           || {}
        max_retry_count  = retry_options[:count]            || DEFAULT_RETRY_COUNT
        reiteration_time = retry_options[:reiteration_time] || DEFAULT_REITERATION_TIME
        sleep_time       = retry_options[:sleep_time]       || DEFAULT_SLEEP_TIME
        
        # Initialize things on the first run for the current request.
        unless data[:vars][:retry]
          data[:vars][:retry]              = {}
          data[:vars][:retry][:count]      = 0
          data[:vars][:retry][:sleep_time] = 0
          # if body is a IO object - remember its initial position in a file
          data[:vars][:retry][:orig_body_stream_pos] = data[:request][:body].is_a?(IO) && data[:request][:body].pos
        else
          # Increment retry attempts count
          data[:vars][:retry][:count] += 1
        end
        
        # Complain on any issue
        fail(Error::new("No more retries left")) if max_retry_count < data[:vars][:retry][:count]
        fail(Error::new("Time is over"))         if Time.now        > data[:vars][:system][:started_at] + reiteration_time
        
        # Continue (with a delay when needed)
        if data[:vars][:retry][:sleep_time] > 0
          cloud_api_logger.log("Sleeping for #{data[:vars][:retry][:sleep_time]} seconds before retry attempt ##{data[:vars][:retry][:count]}", :retry_manager)
          sleep data[:vars][:retry][:sleep_time]
          data[:vars][:retry][:sleep_time] *= 2
        else
          data[:vars][:retry][:sleep_time] = sleep_time
        end
        
        # Restore file pointer in IO body case.
        if data[:request][:instance]                          &&
           data[:request][:instance].is_io?                   &&
           data[:request][:instance].body.respond_to?('pos')  &&
           data[:request][:instance].body.respond_to?('pos=') &&
           data[:request][:instance].body.pos != data[:vars][:retry][:orig_body_stream_pos]
          cloud_api_logger.log("Restoring file position to #{data[:vars][:retry][:orig_body_stream_pos]}", :retry_manager)
          data[:request][:instance].body.pos = data[:vars][:retry][:orig_body_stream_pos]
        end
      end
    end
    
  end
end
