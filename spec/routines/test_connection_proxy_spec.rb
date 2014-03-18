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

require File.expand_path(File.dirname(__FILE__)) + "/../spec_helper"

describe "RightScale::CloudApi::ConnectionProxy" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @connectionproxy = RightScale::CloudApi::ConnectionProxy.new
    @test_data = {}
    @test_data[:options] = {:cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({:logger => logger})}
    @test_data[:callbacks] = {}
    @test_data[:response] = {}
    allow(@connectionproxy).to receive(:log)

  end

  it "creates a close connection callback" do
    proxy = double(:request => nil)
    RightScale::CloudApi::ConnectionProxy::NetHttpPersistentProxy.should_receive(:new).and_return(proxy)
    @connectionproxy.execute(@test_data)
    @test_data[:callbacks][:close_current_connection].should be_a(Proc)
  end
end
