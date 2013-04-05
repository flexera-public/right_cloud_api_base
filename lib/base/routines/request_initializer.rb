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

    # The routine adds a random token to all the GET requests if the corresponding option is enabled.
    #
    class RequestInitializer < Routine

      # Initializes things we may need to initialize.
      #
      # Sometimes we may need to add a random token for every request so that remote cloud. This may
      # be needed when the cloud caches responses for similar requests. Lets say you listed instances
      # then created one and then listed them again. S-me clouds (rackspace) may start to report the
      # new seconds after it was created because of the caching they do.
      #
      # But if we mix something random onto every request then 2 consecutive list instances calls will
      # look like they are different and the cloud wont return the cached data.
      #
      def process
        # Add a random thing to every get request
        if data[:request][:verb] == :get && !data[:options][:random_token]._blank?
          random_token_name = 'rsrcarandomtoken'
          random_token_name = data[:options][:random_token].to_s if [String, Symbol].include?(data[:options][:random_token].class)
          data[:request][:params][random_token_name] = Utils::generate_token
       end
      end
    end

  end
end
