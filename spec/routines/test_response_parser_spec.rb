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


describe "RightScale::CloudApi::ResponseParser" do
  before :each do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @response_parser = RightScale::CloudApi::ResponseParser.new
    @test_data = {}
    @test_data[:request] = { :verb => 'some_verb', :orig_params => {}, :instance => 'some_request'}
    @test_data[:options] = {:error_patterns => [], :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new(
        {:logger => logger, :log_filters => [:response_parser]})
    }
    @callback = double
    @test_data[:callbacks] = {:close_current_connection => @callback}
    @test_data[:connection] = {}
    allow(@response_parser).to receive(:log)
  end


  context "encoding" do
    context "text/xml;charset=UTF-8" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/xml;charset=UTF-8"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Sax.should_receive(:parse).\
          once.with('body', {:encoding => 'UTF-8'})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end


    context "text/xml;charset=utf-8" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/xml;charset=utf-8"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Sax.should_receive(:parse).\
          once.with('body', {:encoding => 'UTF-8'})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end


    context "text/xml;charset=ISO" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/xml;charset=ISO"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Sax.should_receive(:parse).\
          once.with('body', {})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end


    context "text/xml" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/xml"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Sax.should_receive(:parse).\
          once.with('body', {})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end


    context "text/json;charset=ISO" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/json;charset=ISO"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Json.should_receive(:parse).\
          once.with('body', {})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end


    context "text/json;charset=utf-8" do
      before :each do
        response = double(
          :code                => '200',
          :body                => 'body',
          :headers             => {"content-type" => ["text/json;charset=utf-8"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        RightScale::CloudApi::Parser::Json.should_receive(:parse).\
          once.with('body', {:encoding => 'UTF-8'})
      end

      it "works" do
        @response_parser.execute(@test_data)
      end
    end
  end


  context "parsing" do
    context "XML, default" do
      before :each do
        @expectation = {'xml' => { 'a' => '1' }}
        response = double(
          :code                => '200',
          :body                => @expectation._to_xml,
          :headers             => {"content-type" => ["text/xml"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
      end

      it "returns parsed response" do
        @response_parser.execute(@test_data)
        result = @test_data[:result]
        expect(result).to be_a(Hash)
        expect(result).to eq(@expectation)
      end
    end


    context "XML, do not parse flag is set" do
      before :each do
        @expectation = {'xml' => { 'a' => '1' }}
        response = double(
          :code                => '200',
          :body                => @expectation._to_xml,
          :headers             => {"content-type" => ["text/xml"]},
          :is_io?              => false,
          :is_error?           => true,
          :body_info_for_log   => 'body',
          :header_info_for_log => ""
        )
        @test_data[:response] = {:instance => response}
        @test_data[:options][:raw_response] = true
      end

      it "returns raw response" do
        @response_parser.execute(@test_data)
        result = @test_data[:result]
        expect(result).to be_a(String)
        expect(result).to eq(@expectation._to_xml)
      end
    end

  end
end
