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

class TestResponseParser < Test::Unit::TestCase
  def setup
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @response_parser = RightScale::CloudApi::ResponseParser.new
    @test_data = {}
    @test_data[:request] = { :verb => 'some_verb', :orig_params => {}, :instance => 'some_request'}
    @test_data[:options] = {:error_patterns => [], :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new(
        {:logger => logger, :log_filters => [:response_parser]})
    }
    @callback = stub
    @test_data[:callbacks] = {:close_current_connection => @callback}
    @test_data[:connection] = {}
    @response_parser.expects(:log).at_least(0).returns(nil)
  end

  def test_sending_encoding_options
    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/xml;charset=UTF-8]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Sax.expects(:parse).at_least_once.with('body', {:encoding => 'UTF-8'})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/xml;charset=utf-8]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Sax.expects(:parse).at_least_once.with('body', {:encoding => 'UTF-8'})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/xml;charset=ISO]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Sax.expects(:parse).at_least_once.with('body', {})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/xml]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Sax.expects(:parse).at_least_once.with('body', {})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/json;charset=ISO]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Json.expects(:parse).at_least_once.with('body', {})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/json;charset=utf-8]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Json.expects(:parse).at_least_once.with('body', {:encoding => 'UTF-8'})
    @response_parser.execute(@test_data)
  end

  def test_options_for_all_parsers
    response = stub(:code => '200', :body => 'body', :headers => {"content-type" => "[text/xml;charset=UTF-8]"} ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    @test_data[:options].merge!({:xml_parser => 'rexml'})
    RightScale::CloudApi::Parser::ReXml.expects(:parse).at_least_once.with('body', {:encoding => 'UTF-8'})
    @response_parser.execute(@test_data)

    @test_data[:options].merge!({:xml_parser => 'libxml'})
    RightScale::CloudApi::Parser::LibXml.expects(:parse).at_least_once.with('body', {:encoding => 'UTF-8'})
    @response_parser.execute(@test_data)

    response = stub(:code => '200', :body => 'body', :headers => "headers" ,:is_io? => false ,:is_error? => true , :body_info_for_log => 'body', :header_info_for_log => "")
    @test_data[:response] = {:instance => response}
    RightScale::CloudApi::Parser::Plain.expects(:parse).at_least_once.with('body', {})
    @response_parser.execute(@test_data)
  end
end
