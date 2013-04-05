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

describe "RightScale::CloudApi::CacheValidator" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @api_manager = RightScale::CloudApi::ApiManager.new({'x' => 'y'},'endpoint', {:logger => logger})
    @api_manager.class.set_routine RightScale::CloudApi::CacheValidator
    @api_manager.class.options[:error_patterns] = []

    @cachevalidator = RightScale::CloudApi::CacheValidator.new
    @test_data = {}
    @test_data[:request] = { :verb => 'some_verb', :orig_params => {}, :instance => 'some_request'}
    @test_data[:options] = {:error_patterns => []}
    @callback = stub
    @test_data[:options][:cache] = {}
    @test_data[:callbacks] = {:close_current_connection => @callback}
    @test_data[:connection] = {}
    @test_data[:response] = {}
    @test_data[:vars] = {:system => {:storage => {}}}
    @test_data[:response][:instance] = stub(:is_io? => false)
    @cachevalidator.stub(:log => nil)
  end

  context "cache_pattern" do
    it "fails when is has unexpected inputs" do
      # non hash input
      lambda { @api_manager.class.cache_pattern(true) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
      # blank pattern
      lambda { @api_manager.class.cache_pattern({}) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
    end

    context "pattern keys" do
      before(:each) do
        # test all pattern keys
        @cache_pattern = RightScale::CloudApi::CacheValidator::ClassMethods::CACHE_PATTERN_KEYS.inject({}) { |result, k| result.merge(k => k.to_s)}
        @api_manager.class.cache_pattern(@cache_pattern)
      end
      it "stores all the cache patterns keys properly" do
        @api_manager.class.options[:cache_patterns].should == [@cache_pattern]
      end
      it "complains when a mandatory key is missing" do
        @cache_pattern.delete(:key)
        lambda { @api_manager.class.cache_pattern(@cache_pattern) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
      end
      it "complains when an unsupported key is passed" do
        bad_keys = { :bad_key1 => "bad_key1", :bad_key2 => "bad_key2" }
        @cache_pattern.merge!(bad_keys)
        lambda { @api_manager.class.cache_pattern(@cache_pattern) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
      end
    end
  end

  context "basic cache validation" do
    it "returns true when it performed validation" do
      @cachevalidator.execute(@test_data).should be(true)
    end
    it "returns nil if there is no way to parse a response object" do
      @test_data[:response][:instance] = stub(:is_io? => true)
      @cachevalidator.execute(@test_data).should be(nil)
    end
    it "returns nil if caching is disabled" do
      @test_data[:options].delete(:cache)
      @cachevalidator.execute(@test_data).should be(nil)
    end
  end

  context "cache validation with match" do
    before(:each) do
      RightScale::CloudApi::Utils.should_receive(:pattern_matches?).at_least(1).and_return(true)
      @cache_pattern = RightScale::CloudApi::CacheValidator::ClassMethods::CACHE_PATTERN_KEYS.inject({}) { |result, k| result.merge(k  => k.to_s)}
      @cache_pattern[:sign] = stub(:call => "body_to_sign")
      @test_data[:options][:cache_patterns] = [@cache_pattern]
      @response = stub(:code => '501', :body => 'body', :headers => 'headers', :is_io? => false)
      @test_data[:response] = {:instance => @response}
    end
    it "fails if there is a missing key" do
      @cache_pattern.delete(:key)
      lambda { @cachevalidator.execute(@test_data) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
    end
    
    context "and one record cached" do
      before(:each) do
        @cachevalidator.should_receive(:build_cache_key).at_least(1).and_return(["some_key","some_response_body"])
        @cachevalidator.should_receive(:log).with("New cache record created")
        @cachevalidator.execute(@test_data)
      end
      it "succeeds when it builds a cache key for the first time" do
        @test_data[:vars][:cache][:key].should == "some_key"
      end
      it "raises CacheHit and increments a counter when cache hits" do
        lambda { @cachevalidator.execute(@test_data) }.should raise_error(RightScale::CloudApi::CacheHit)
        @test_data[:vars][:system][:storage][:cache]['some_key'][:hits].should == 1
        lambda { @cachevalidator.execute(@test_data) }.should raise_error(RightScale::CloudApi::CacheHit)
        @test_data[:vars][:system][:storage][:cache]['some_key'][:hits].should == 2
      end
      it "replaces a record if the same request gets a different response" do
        @test_data[:vars][:system][:storage][:cache]['some_key'][:md5] = 'corrupted'
        @cachevalidator.should_receive(:log).with("Missed. Record is replaced")
        @cachevalidator.execute(@test_data)
        @test_data[:vars][:system][:storage][:cache]['some_key'][:hits].should == 0
      end
    end
  end

  context "build_cache_key" do
    before(:each) do
      # use send since this is a private method
      @opts = {:response => stub(:body => nil)}
    end
    it "fails when it cannot create a key" do
      lambda { @cachevalidator.__send__(:build_cache_key, {}, @opts) }.should raise_error((RightScale::CloudApi::CacheValidator::Error))
    end
    it "fails when it cannot create body" do
      lambda { @cachevalidator.__send__(:build_cache_key, {:key => 'normal_key'}, @opts) }.should raise_error(RightScale::CloudApi::CacheValidator::Error)
    end
    it "creates key and body from given inputs" do
      pattern = {:key => 'normal_key'}
      opts    = {:response => stub(:body => "normal_body")}
      @cachevalidator.__send__(:build_cache_key, pattern, opts).should == ['normal_key', 'normal_body']
    end
    it "creates key and body from given procs" do
      proc = stub(:is_a? => true)
      proc.should_receive(:call).and_return("proc_key")
      proc_pattern = { :key => proc, :sign => stub(:call => "proc_sign_call") }
      @cachevalidator.__send__(:build_cache_key, proc_pattern, @opts).should == ['proc_key', 'proc_sign_call']
    end
  end
end
