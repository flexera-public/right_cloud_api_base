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

require File.expand_path(File.dirname(__FILE__)) + "/../../spec_helper"
require "net/http/persistent"

describe "RightScale::CloudApi::ConnectionProxy::NetHTTPPersistentProxy" do
  before(:each) do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @proxy = RightScale::CloudApi::ConnectionProxy::NetHttpPersistentProxy.new
    @uri = double(:host   => 'host.com',
                  :port   => '777',
                  :scheme => 'scheme',
                  :dup    => @uri)
    @test_data = {
      :options     => {:user_agent => 'user_agent_data',
                       :connection_retry_count => 0,
                       :cloud_api_logger => RightScale::CloudApi::CloudApiLogger.new({:logger => logger})},
      :credentials => {},
      :callbacks   => {},
      :vars        => {:system => {:block => 'block'}},
      :request     => {:instance => double(:verb => 'get',
                                         :path     => 'some/path',
                                         :body     => 'body',
                                         :is_io?   => false,
                                         :headers  => {'header1' => 'val1',
                                                       'header2' => 'val2'},
                                         :raw=     => nil)},
      :connection  => {:uri => @uri}
    }
    @response = double(:code => '200', :body => 'body', :to_hash => {:code => '200', :body => 'body'})
  end


  context "when request succeeds" do
    before :each do
      @connection = double(
        :request                => @response,
        :retry_change_requests= => true,
        :shutdown               => true )
      expect(Net::HTTP::Persistent).to receive(:new).and_return(@connection)
    end

    it "works" do
      @proxy.request(@test_data)
    end
  end


  context "when there is a connection issue" do
    before :each do
      @connection = double( :retry_change_requests= => true )
      expect(Net::HTTP::Persistent).to receive(:new).and_return(@connection)
      # failure in the connection should finish and reraise the error
      expect(@connection).to receive(:request).and_raise(SocketError.new("Something went wrong"))
      expect(@connection).to receive(:shutdown)
    end

    it "produces a correct error message" do
      expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError, "SocketError: Something went wrong")
    end
  end


  context "low level connection retries" do
    before :each do
      @connection = double(
        :retry_change_requests= => true,
        :shutdown => true
       )
      expect(Net::HTTP::Persistent).to receive(:new).and_return(@connection)
    end

    context "when retries are disabled" do
      before:each do
        expect(@connection).to receive(:request).and_raise( Timeout::Error)
        @test_data[:options][:connection_retry_count] = 0
        expect(@proxy).to receive(:sleep).never
      end

      it "makes no retries" do
        expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError)
      end
    end


    context "when retries are enabled" do
      context "timeouts are enabled" do
        before:each do
          @retries_count = 3
          expect(@connection).to receive(:request).exactly(@retries_count+1).times.and_raise( Timeout::Error)
          @test_data[:options][:connection_retry_count] = @retries_count
          expect(@proxy).to receive(:sleep).exactly(@retries_count).times
        end

        it "makes no retries" do
          expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError)
        end
      end


      context "but timeouts are disabled" do
        before:each do
          @retries_count = 3
          @test_data[:options][:connection_retry_count] = @retries_count
          @test_data[:options][:abort_on_timeout] = true
        end

        it "makes no retries on timeout" do
          expect(@connection).to receive(:request).and_raise(Timeout::Error)
          expect(@proxy).to receive(:sleep).never
          expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError)
        end

        it "makes retries on non timeout errors" do
          expect(@connection).to receive(:request).exactly(@retries_count+1).times.and_raise(SocketError)
          expect(@proxy).to receive(:sleep).exactly(@retries_count).times
          expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError)
        end
      end

      context "when there is a connection issue(Address family not supported by protocol)" do
        before:each do
          @retries_count = 3
          @test_data[:options][:connection_retry_count] = @retries_count
        end

        it "makes retries" do
          expect(@connection).to receive(:request).exactly(@retries_count+1).times.and_raise(Errno::EAFNOSUPPORT)
          expect(@proxy).to receive(:sleep).exactly(@retries_count).times
          expect { @proxy.request(@test_data) }.to raise_error(RightScale::CloudApi::ConnectionError)
        end
      end
    end
  end
end
