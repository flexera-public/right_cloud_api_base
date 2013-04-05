require 'right_cloud_api_base'
require 'spec'

# Generates a fake response object.
#
# @param [String] code HTTP response code
# @param [String] body HTTP response body
# @param [Hash]   headers HTTP response code
# @param [HttpResponse] raw HTTP response object
#
# @return [RightScale::CloudApi::HTTPResponse]
#
def generate_http_response(code, body='body', headers={}, raw=nil)
  RightScale::CloudApi::HTTPResponse.new(code.to_s, body, headers, raw)
end