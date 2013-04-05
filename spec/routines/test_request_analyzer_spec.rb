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

describe "RightScale::CloudApi::RequestAnalyzer" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @api_manager = RightScale::CloudApi::ApiManager.new({'x' => 'y'},'endpoint', {:logger => logger})
    @api_manager.class.set_routine RightScale::CloudApi::RequestAnalyzer
    @api_manager.class.options[:error_patterns] = []
  end

  context "request keys" do
    before(:each) do
      @valid_request_keys    = RightScale::CloudApi::RequestAnalyzer::REQUEST_KEYS.inject({}) { |result, k| result.merge(k  => k.to_s)}
      @valid_request_actions = RightScale::CloudApi::RequestAnalyzer::REQUEST_ACTIONS
    end
    it "creates a pattern for expected keys" do
      expected_result = []
      @valid_request_actions.each do |action|
        expected_result << @valid_request_keys.merge(:action => action)
        @api_manager.class.error_pattern(action, @valid_request_keys).should == expected_result
      end
    end
  end

  context "response keys" do
    before(:each) do
      @valid_response_keys    = RightScale::CloudApi::RequestAnalyzer::RESPONSE_KEYS.inject({}) { |result, k| result.merge(k  => k.to_s)}
      @valid_response_actions = RightScale::CloudApi::RequestAnalyzer::RESPONSE_ACTIONS
    end
    it "creates a pattern for expected keys" do
      expected_result = []
      @valid_response_actions.each do |action|
        expected_result << @valid_response_keys.merge(:action => action)
        @api_manager.class.error_pattern(action, @valid_response_keys).should == expected_result
      end
    end
  end

  context "with unexpected keys" do
    it "fails to create a pattern" do
      valid_request_action = :abort_on_timeout
      lambda { @api_manager.class.error_pattern(valid_request_action, {:bad_key => "BadKey"}) }.should raise_error(RightScale::CloudApi::RequestAnalyzer::Error)
      lambda { @api_manager.class.error_pattern(:bad_action, {:verb => /verb/}) }.should raise_error(RightScale::CloudApi::RequestAnalyzer::Error)
      lambda { @api_manager.class.error_pattern(valid_request_action, {:response => /verb/}) }.should raise_error(RightScale::CloudApi::RequestAnalyzer::Error)
    end
  end

  context "process" do
    before(:each) do
      logger         = Logger.new(STDOUT)
      logger.level   = Logger::INFO
      error_patterns = [{:path   =>/Action=(Run|Create)/,
                         :action =>:abort_on_timeout},
                        {:response => /InternalError|Internal Server Error|internal service error/i,
                         :action   => :retry}]
      @data = {:request => {:instance    => 'some_instance',
                            :verb        => 'some_verb',
                            :orig_params => {}},
               :options => {:error_patterns   => error_patterns,
                            :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({:logger => logger,
                                                                                           :log_filters => [:request_generator] })}}
      @requestanalyzer = RightScale::CloudApi::RequestAnalyzer.new
      @requestanalyzer.stub(:log => nil)
    end

    context "when patern does not match" do
      it "does not set :abort_on_timeout flag" do
        RightScale::CloudApi::Utils.should_receive(:pattern_matches?).and_return(false)
        @requestanalyzer.execute(@data)
        @data[:options].has_key?(:abort_on_timeout).should be(false)
      end
    end

    context "when patern matches" do
      it "sets :abort_on_timeout flag" do
        RightScale::CloudApi::Utils.should_receive(:pattern_matches?).and_return(true)
        @requestanalyzer.execute(@data)
        @data[:options][:abort_on_timeout].should be(true)
      end
    end
  end
end