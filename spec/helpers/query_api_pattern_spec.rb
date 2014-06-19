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
require "base/helpers/query_api_patterns"

module RightScale
  module CloudApi
    module Test

      class FakeRoutine < Routine
        def process
          @data[:result] = @data.dup
        end
      end
      
      class ApiManager < RightScale::CloudApi::ApiManager
        include RightScale::CloudApi::Mixin::QueryApiPatterns
        
        set_routine FakeRoutine
        
        query_api_pattern :GetService, :get
        
        query_api_pattern :GetResource, :get, 'resource/1'
        
        query_api_pattern :GetResourceWithHardcodedData, :get, 'resource/1', 
                       :params  => { 'p1' => 1, 'p2' => 2 }, 
                       :headers => { 'x-text-header' => 'my-test-value' },
                       :body    => 'MyTestStringBody'
                     
        query_api_pattern :GetResourceWithVars, :get, 'resource/{:ResourceId}',
                       :params  => { 'p1' => :Param1, 'p2' => :Param2 }, 
                       :headers => { 'x-text-header' => :MyHeader },
                       :body    => :MyBody
                     
        query_api_pattern :GetResourceWithFlexibleVars, :get,'resource/{:ResourceId}/subresource/{:SubresourceId}',
                       :headers => { 'x-text-header' => "{:MyHeaderSource}/{:MyHeaderKey}" },
                       :body    => "text-{:BodyParam1}-text-again-{:BodyParam2}"
                     
        query_api_pattern :GetResourceWithFlexibleVarsAndDefaults, :get,'resource/{:ResourceId}/subresource/{:SubresourceId}',
                       :headers => { 'x-text-header' => "{:MyHeaderSource}/{:MyHeaderKey}" },
                       :body    => "text-{:BodyParam1}-text-again-{:BodyParam2}",
                       :defaults => {
                         :BodyParam2     => Utils::NONE,
                         :SubresourceId  => 2,
                         :MyHeaderSource => 'something'
                       }

        query_api_pattern :GetResourceWithFlexibleVarsAndDefaultsV2, :get, '',
                       :body    => {
                         'Key1' => 'Value1',
                         'Key2' => :Value2,
                         'Key3' => {
                           'Key4' => :Value4
                         }
                       },
                       :defaults => {
                         :Value4 => Utils::NONE,
                       }

        query_api_pattern :GetResourceWithFlexibleVarsAndCollection, :get, '',
                       :body    => {
                         'Key1' => :Value1,
                         'Collection[{:Items}]' => {
                           'Name'  => :Name,
                           'Value' => :Value
                         },
                         'Collection2[]' => {
                           'Name2'  => :Name2,
                           'Value2' => :Value2
                         }
                       },
                       :defaults => {
                         :Value => 13,
                       }

        query_api_pattern :GetResourceWithSubCollectionReplacement, :get, '',
                       :body    => {
                         'Key1' => :Value1,
                         'Collections{:Collections}' => {
                           'Collection[{:Items}]' => {
                             'Name'  => :Name,
                             'Value' => :Value
                           }
                         }
                       },
                       :defaults => {
                         :Value => 13
                       }

        query_api_pattern :GetResourceWithSubCollectionReplacementAndDefaults, :get, '',
                       :body    => {
                         'Key1' => :Value1,
                         'Collections{:Collections}' => {
                           'Collection[{:Items}]' => {
                             'Name'  => :Name,
                             'Value' => :Value
                           }
                         }
                       },
                       :defaults => {
                         :Value => 13,
                         :Collections => Utils::NONE
                       }

        query_api_pattern(:GetResourceWithBlock, :get, 'resource/1') do |result|
          result[:path] = 'my-new-path'
          result[:verb] = :post
          result[:params]  = {'p1' => 'v1'}
          result[:headers] = {'x-my-header' => 'value'}
          result[:body]    = 'MyBody'
        end

        query_api_pattern :GetResourceWithProc, :get, 'resource/1',
          :after => Proc.new { |result| result[:path] = 'my-new-path'
                                        result[:verb] = :post
                                        result[:params]  = {'p1' => 'v1'}
                                        result[:headers] = {'x-my-header' => 'value'}
                                        result[:body]    = 'MyBody' }
      end
      
    end
  end
end

describe "QueryApiPattern" do
  before(:each) do
    unless @initialized
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      @api_manager = RightScale::CloudApi::Test::ApiManager.new({'x' => 'y'},'endpoint', {:logger => logger})
    end
  end

  context "query_api_pattern" do
    it "fails when there is an unexpected parameter" do
      expect {
        @api_manager.class.query_api_pattern(:GetService, :get, '', :unknown_something => 'blah-blah')
      }.to raise_error(RightScale::CloudApi::Error)
    end
  end

  it "works when there are no issues and generates request data properly" do
    data    = @api_manager.GetService
    request = data[:request]
    expect(request[:verb]).to eq(:get)
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body].nil?).to be(true)
  end

  it "moves all unused variables into URL params" do
    data    = @api_manager.GetService('Param1' => 'value1', 'Param2' => 'value2')
    request = data[:request]
    expect(request[:verb]).to eq(:get)
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]).to eq('Param1' => 'value1', 'Param2' => 'value2')
    expect(request[:body]).to be(nil)
  end

  it "works for GetResource Query API definition" do
    data    = @api_manager.GetResource
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]).to eq 'resource/1'
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body]).to be(nil)
  end

  it "works for GetResourceWithHardcodedData Query API definition" do
    data    = @api_manager.GetResourceWithHardcodedData
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]).to eq 'resource/1'
    expect(request[:headers].to_hash).to eq('x-text-header' => ['my-test-value'])
    expect(request[:params]).to eq('p1' => 1, 'p2' => 2 )
    expect(request[:body]).to eq 'MyTestStringBody'
  end

  it "works for GetResourceWithVars Query API definition" do
    data    = @api_manager.GetResourceWithVars( 'ResourceId' => 123, 'Param1' => 11, 'Param2' => 12, 'MyHeader' => 'x-test-something', 'MyBody' => 'MyTestStringBody')
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]).to eq 'resource/123'
    expect(request[:headers].to_hash).to eq('x-text-header' => ['x-test-something'])
    expect(request[:params]).to eq( 'p1' => 11, 'p2' => 12 )
    expect(request[:body]).to eq 'MyTestStringBody'
  end

  it "fails when a mandatory variable is missing" do
    expect{ @api_manager.GetResourceWithVars }.to raise_error(RightScale::CloudApi::Error)
  end

  it "works for GetResourceWithFlexibleVars Query API definition" do
    data    = @api_manager.GetResourceWithFlexibleVars( 'ResourceId' => 1, 'SubresourceId' => 2, 'MyHeaderSource' => 3, 'MyHeaderKey' => 4, 'BodyParam1' => 5, 'BodyParam2' => 6)
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]).to eq 'resource/1/subresource/2'
    expect(request[:headers].to_hash).to eq('x-text-header' => ['3/4'])
    expect(request[:body]).to eq 'text-5-text-again-6'
  end

  it "works for GetResourceWithFlexibleVarsAndDefaults Query API definition" do
    data    = @api_manager.GetResourceWithFlexibleVarsAndDefaults('ResourceId' => 1, 'MyHeaderKey' => 3, 'BodyParam1' => 5)
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]).to eq 'resource/1/subresource/2'
    expect(request[:headers].to_hash).to eq('x-text-header' => ['something/3'])
    expect(request[:body]).to eq 'text-5-text-again-'
  end

  it "works for GetResourceWithFlexibleVarsAndDefaultsV2 Query API definition" do
    data    = @api_manager.GetResourceWithFlexibleVarsAndDefaultsV2('Value2' => 1)
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body]).to eq('Key1' => 'Value1', 'Key2' => 1, 'Key3' => {})
  end

  it "works for GetResourceWithFlexibleVarsAndCollection Query API definition" do
    data    = @api_manager.GetResourceWithFlexibleVarsAndCollection('Value1' => 1,
                'Items' => [{'Name' => 'x1', 'Value' => 'xv1'}, {'Name' => 'x2'}],
                'Collection2' => [{'Name2' => 'x21', 'Value2' => 'xv21'}, {'Name2' => 'x22', 'Value2' => 'v22'}]
              )
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body]).to eq('Key1' => 1,
                              'Collection' => [{'Name' => 'x1', 'Value' => 'xv1'}, {'Name' => 'x2', 'Value' => 13}],
                              'Collection2' => [{'Name2' => 'x21', 'Value2' => 'xv21'}, {'Name2' => 'x22', 'Value2' => 'v22'}])
  end

  it "works for GetResourceWithSubCollectionReplacement Query API definition" do
    # Nothing is pased - should complain
    expect {
      @api_manager.GetResourceWithSubCollectionReplacement('Value1' => 1)
    }.to raise_error(RightScale::CloudApi::Error)
    # A replacement is passed - must replace
    data    = @api_manager.GetResourceWithSubCollectionReplacement('Value1' => 1, 'Collections' => 'blah-blah')
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body]).to eq('Key1' => 1, 'Collections' => 'blah-blah')

    data    = @api_manager.GetResourceWithSubCollectionReplacement('Value1' => 1, 'Items' => [{'Name' => 'x1', 'Value' => 'xv1'}, {'Name' => 'x2'}])
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to  be(true)
    expect(request[:body]).to eq('Key1' => 1, 'Collections' => {'Collection' => [{'Name' => 'x1', 'Value' => 'xv1'}, {'Name' => 'x2', 'Value' => 13}]})
  end

  it "works for GetResourceWithSubCollectionReplacementAndDefaults Query API definition" do
    data    = @api_manager.GetResourceWithSubCollectionReplacementAndDefaults('Value1' => 1)
    request = data[:request]
    expect(request[:verb]).to eq :get
    expect(request[:relative_path]._blank?).to be(true)
    expect(request[:headers].to_hash._blank?).to be(true)
    expect(request[:params]._blank?).to be(true)
    expect(request[:body]).to eq('Key1' => 1 )
  end

  it "works for GetResourceWithBlock Query API definition" do
    data    = @api_manager.GetResourceWithBlock
    request = data[:request]
    expect(request[:verb]).to eq :post
    expect(request[:relative_path]).to eq 'my-new-path'
    expect(request[:headers].to_hash).to eq('x-my-header' => ['value'])
    expect(request[:params]).to eq( 'p1' => 'v1')
    expect(request[:body]).to eq 'MyBody'
  end

  it "works for GetResourceWithProc Query API definition" do
    data    = @api_manager.GetResourceWithProc
    request = data[:request]
    expect(request[:verb]).to eq :post
    expect(request[:relative_path]).to eq 'my-new-path'
    expect(request[:headers].to_hash).to eq('x-my-header' => ['value'])
    expect(request[:params]).to eq( 'p1' => 'v1')
    expect(request[:body]).to eq 'MyBody'
  end
end