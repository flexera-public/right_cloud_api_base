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

describe "" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @retrymanager = RightScale::CloudApi::RetryManager.new
    @retrymanager.stub(:log => nil)
    @request = stub(:verb => 'get', :path => 'some/path', :body => 'body', :is_io? => false, :is_error? => false, :is_redirect? => false, :headers => {'header1' => 'val1', 'header2' => 'val2'})
    @test_data = {
      :options     => { :user_agent => 'user_agent_data',
                        :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({})},
      :vars        => { :system => {:block => 'block', :started_at => Time.now}},
      :credentials => {},
      :callbacks   => {},
      :connection  => {:uri => stub(:host => 'host.com', :port => '777', :scheme => 'scheme')},
      :request     => {:instance => @request}
    }
    @response   = stub(:code => '200', :body => 'body', :to_hash => {:code => '200', :body => 'body'})
    @connection = stub(:request => @response)
  end

  context "RightScale::CloudApi::RetryManager" do
    it "works" do
      # 1st run
      @retrymanager.execute(@test_data)
      @test_data[:vars][:retry][:count] .should     == 0
      @test_data[:vars][:retry][:sleep_time].should == 0.2
      # 2nd run, +1 count *2 sleep
      @retrymanager.execute(@test_data)
      @test_data[:vars][:retry][:count].should == 1
      @test_data[:vars][:retry][:sleep_time].should == 0.4
      # 3rd run, +1 count, *2 sleep
      @retrymanager.execute(@test_data)
      @test_data[:vars][:retry][:count].should == 2
      @test_data[:vars][:retry][:sleep_time].should == 0.8
    end
  end
end
