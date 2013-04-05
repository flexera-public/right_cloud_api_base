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

require 'rubygems'
require 'time'
require 'openssl'
require 'net/https'
require 'base64'
require 'cgi'
require 'logger'
require 'digest/md5'

$:.unshift(File::expand_path(File::dirname(__FILE__)))

require "right_cloud_api_base_version"

# Helpers
require "base/helpers/support"
require "base/helpers/support.xml"
require "base/helpers/utils"
require "base/helpers/net_http_patch"
require "base/helpers/http_headers"
require "base/helpers/http_parent"
require "base/helpers/http_request"
require "base/helpers/http_response"
require "base/helpers/query_api_patterns"
require "base/helpers/cloud_api_logger"

# Managers
require "base/manager"
require "base/api_manager"

# Default parsers
require "base/parsers/plain"
require "base/parsers/json"
require "base/parsers/rexml"
require "base/parsers/sax"

# Default routines
require "base/routines/routine"
require "base/routines/retry_manager"
require "base/routines/request_initializer"
require "base/routines/request_generator"
require "base/routines/connection_proxy"
require "base/routines/connection_proxies/right_http_connection_proxy"
require "base/routines/connection_proxies/net_http_persistent_proxy"
require "base/routines/response_parser"
require "base/routines/request_analyzer"
require "base/routines/response_analyzer"
require "base/routines/cache_validator"
require "base/routines/result_wrapper"

