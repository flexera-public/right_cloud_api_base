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

describe "RightScale::CloudApi::ConnectionProxy::RightHttpConnectionProxy" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @righthttpconnectionproxy = RightScale::CloudApi::ConnectionProxy::RightHttpConnectionProxy.new
    @uri = stub(:host   => 'host.com',
                :port   => '777',
                :scheme => 'scheme')
    @uri.stub(:dup => @uri)
    @test_data = {
      :options     => {:user_agent => 'user_agent_data',
                       :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({:logger => logger})},
      :credentials => {},
      :callbacks   => {},
      :vars        => {:system => {:block => 'block'}},
      :request     => {:instance => stub(:verb => 'get',
                                         :path     => 'some/path',
                                         :body     => 'body',
                                         :is_io?   => false,
                                         :headers  => {'header1' => 'val1',
                                                       'header2' => 'val2'},
                                         :raw=     => nil)},
      :connection  => {:uri => @uri}
    }
    @righthttpconnectionproxy.stub(:log => nil)
    @response   = stub(:code => '200', :body => 'body', :to_hash => {:code => '200', :body => 'body'})
    @connection = stub(:request => @response)
  end

  it "works" do
    # should run through without any exceptions
    @righthttpconnectionproxy.should_receive(:current_connection).and_return(@connection)
    @righthttpconnectionproxy.request(@test_data)

    # failure in the connection should finish and reraise the error
    @connection.should_receive(:finish)
    @connection.should_receive(:request ).and_raise(Exception.new("something really bad happened with your request"))
    @righthttpconnectionproxy.should_receive(:current_connection).and_return(@connection)
    lambda { @righthttpconnectionproxy.request(@test_data) }.should raise_error(Exception)
  end
end
