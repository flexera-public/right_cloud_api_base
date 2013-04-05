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

describe "RightScale::CloudApi::ResultWrapper" do
  before (:each)   do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @resultwrapper = RightScale::CloudApi::ResultWrapper.new
    @test_data = {}
    @test_data[:options] = { :user_agent       => 'user_agent_data',
                             :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({:logger => logger})}
    @test_data[:vars] = {}
    @test_data[:callbacks] = {}
    @headers = { 'header1' => ['1'], 'header2' => ['2'] }
    @response= generate_http_response(201, 'body', @headers)
    @test_data[:response] = {:instance => @response, :parsed => "parsed_response"}
    @resultwrapper.stub(:log => nil)
    @test_data[:vars][:current_cache_key] = "cache_key"
    @test_data[:vars][:cache] = {'cache_key' => { :key => 'old_cache_record_key', :record => 'haha' }}
    @result = @resultwrapper.execute(@test_data)
  end

  context "metadata" do
    it "looks like a parsed body object but responds to metadata" do
      @result.should == 'parsed_response'
      @result.should be_a(String)
      lambda { @result.metadata }.should_not raise_error
    end
    it "contains the last respose headers and code" do
      @result.metadata[:headers].should == @headers
      @result.metadata[:code].should == @response.code
    end
    it "may contain the cache key" do
      @result.metadata[:cache].should == @test_data[:vars][:cache]
    end
  end
end