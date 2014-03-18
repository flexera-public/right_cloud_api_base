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

describe "RightScale::CloudApi::ResponseAnalyzer" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @responseanalyzer = RightScale::CloudApi::ResponseAnalyzer.new
    @test_data = {}
    @test_data[:request] = { :verb => 'some_verb', :orig_params => {}, :instance => 'some_request'}
    @test_data[:vars]    = { :retry => {} }
    @test_data[:options] = {:error_patterns => [], :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new(
        {:logger => logger, :log_filters => [:response_analyzer, :response_analyzer_body_error]})
    }
    @close_current_connection_callback = double
    @test_data[:callbacks] = {:close_current_connection => @close_current_connection_callback}
    @test_data[:connection] = {}
    allow(@responseanalyzer).to receive(:log)
  end

  context "with no error patterns" do
    it "fails on 5xx, 4xx errors" do
      [500, 400].each do |http_error|
        @test_data[:response] = {:instance => generate_http_response(http_error)}
        lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::HttpError)
      end
    end
    it "fails on redirect when there is no location tin the response" do
      @test_data[:response] = {:instance => generate_http_response(300)}
      lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::HttpError)
    end
    it "works for 2xx codes" do
      @test_data[:response] = {:instance => generate_http_response(200)}
      lambda { @responseanalyzer.execute(@test_data) }.should_not raise_error
    end
  end

  context "when retry is requested" do
    before(:each) do
      error_patterns = [{:action => :retry}]
      @test_data[:options][:error_patterns] = error_patterns
      allow(RightScale::CloudApi::Utils).to receive(:pattern_matches?).and_return(true)
    end
    it "raises a retry attempt exception for 4xx and 5xx errors" do
      [500, 400].each do |http_error|
        @test_data[:response] = {:instance => generate_http_response(http_error)}
        lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::RetryAttempt)
      end
    end
    it "fails when there is no location for 3xx redirect" do
      response = generate_http_response(301, 'body', {'location' => ''})
      @test_data[:response] = {:instance => response}
      lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::HttpError)
    end
    it "raises a retry attempt exception when there is a location (in headers) for 3xx redirect" do
      response = generate_http_response(301, 'body', {'location' => 'www.some-new-location.com'})
      @test_data[:response] = {:instance => response}
      lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::RetryAttempt)
    end
    it "raises a retry attempt exception when there is a location (in body) for 3xx redirect" do
      response = generate_http_response(301, '<Endpoint> www.some-new-location.com </Endpoint>', {'location' => ''})
      @test_data[:response] = {:instance => response}
      uri_object = double(:host= => 'www.some-new-location.com', :to_s => 'www.some-new-location.com')
      @test_data[:connection][:uri] = uri_object
      lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::RetryAttempt)
    end
  end

  context "when reconnect_and_retry is requested" do
    before(:each) do
      @test_data[:options][:error_patterns] = [{:action => :reconnect_and_retry}]
      RightScale::CloudApi::Utils.should_receive(:pattern_matches?).at_least(1).and_return(true)
      @close_current_connection_callback.should_receive(:call).twice.with('Error pattern match')
    end
    it "raises a retry attempt exception for 4xx and 5xx errors" do
      [500, 400].each do |http_error|
        @test_data[:response] = {:instance => generate_http_response(http_error)}
        lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::RetryAttempt)
      end
    end
  end

  context "when disconnect_and_abort is requested" do
    before(:each) do
      @test_data[:options][:error_patterns] = [{:action => :disconnect_and_abort}]
      RightScale::CloudApi::Utils.should_receive(:pattern_matches?).at_least(1).and_return(true)
      @close_current_connection_callback.should_receive(:call).twice.with('Error pattern match')
    end
    it "failse for 4xx and 5xx errors" do
      [500, 400].each do |http_error|
        @test_data[:response] = {:instance => generate_http_response(http_error)}
        lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::HttpError)
      end
    end
  end

  context "when abort is requested" do
    before(:each) do
      @test_data[:options][:error_patterns] = [{:action => :abort}]
      RightScale::CloudApi::Utils.should_receive(:pattern_matches?).at_least(1).and_return(true)
      @close_current_connection_callback.should_receive(:call).never
    end
    it "failse for 4xx and 5xx errors" do
      [500, 400].each do |http_error|
        @test_data[:response] = {:instance => generate_http_response(http_error)}
        lambda { @responseanalyzer.execute(@test_data) }.should raise_error(RightScale::CloudApi::HttpError)
      end
    end
  end
end
