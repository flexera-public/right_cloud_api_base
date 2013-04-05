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

describe "support.rb" do

  # --- String ---

  context "String#_constantize" do
    it "constantizes when a string points to an existing class/module name" do
      class MyCoolTestConstantizeClass; end
      'MyCoolTestConstantizeClass'._constantize.should == MyCoolTestConstantizeClass
    end
    it "fails when a string points to a non-existing class/module name" do
      lambda {
       'MyBadTestConstantizeClass'._constantize
      }.should raise_error(::NameError)
    end
  end

  context "String#_camelize" do
    it "camelizes a string" do
      'my_test_string'._camelize.should == 'MyTestString'
      'MyTestString'._camelize.should == 'MyTestString'
      'my_test_string'._camelize(:lower_case).should == 'myTestString'
      'MyTestString'._camelize(:lower_case).should == 'myTestString'
      'Privet, how are you_doing, los_Amigos?'._camelize.should == 'Privet, How Are YouDoing, LosAmigos?'
    end
  end

  context "String#_snake_case" do
    it "underscorizes a string" do
      'MyTestString'._snake_case.should == 'my_test_string'
      'my_test_string'._snake_case.should == 'my_test_string'
      'Privet, How Are YouDoing, LosAmigos?'._snake_case.should == 'privet, how are you_doing, los_amigos?'
    end
  end

  context "String#_arrayify" do
    it "arrayifies into array" do
      ''._arrayify.should == ['']
      'something'._arrayify.should == ['something']
    end
  end

  context "String#_blank?" do
    it "returns true when it has zero size" do
      ''._blank?.should == true
    end
    it "returns true when it contains spaces only" do
      "   \n\n\n   "._blank?.should == true
    end
    it "returns false when it has anything valueble" do
      "something"._blank?.should == false
    end
  end

  # --- Object ---

  context "Object#_blank?" do
    it "checks if an object responds blank?" do
      object = Object.new
      object.should_receive(:respond_to?).with(:blank?).once.and_return(true)
      object.should_receive(:blank?).once.and_return(true)
      object._blank?.should == true
    end
    it "checks if an object responds empty? unles it responds to blank?" do
      object = Object.new
      object.should_receive(:respond_to?).with(:blank?).once.and_return(false)
      object.should_receive(:respond_to?).with(:empty?).once.and_return(true)
      object.should_receive(:empty?).once.and_return(true)
      object._blank?.should == true
    end
    it "returns !self unless it responds to blank? and empty?" do
      object = Object.new
      object.should_receive(:respond_to?).with(:blank?).once.and_return(false)
      object.should_receive(:respond_to?).with(:empty?).once.and_return(false)
      object._blank?.should == !object
    end
  end

  context "Object#_arrayify" do
    it "feeds self to Array()" do
      [nil, 1, :symbol].each do |object|
        object._arrayify.should == Array(object)
      end
    end
  end

  # --- NilClass ---

  context "NilClass" do
    it "always return true" do
      nil._blank?.should == true
    end
  end

  # --- FalseClass ---

  context "FalseClass" do
    it "always return true" do
      false._blank?.should == true
    end
  end

  # --- TrueClass ---

  context "FalseClass" do
    it "always return false" do
      true._blank?.should == false
    end
  end

  # --- Array ---

  context "Array#_blank?" do
    it "behaves accordingly to array's emptyness status" do
      []._blank?.should == true
      [1]._blank?.should == false
    end
  end

  context "Array#_stringify_keys" do
    it "stringifies all the keys for all its hash items" do
      [[{:x=>{:y=>[:z => 13]}}]]._stringify_keys.should ==
        [[{"x"=>{"y"=>[{"z"=>13}]}}]]
    end
  end

  context "Array#_stringify_keys" do
    it "symbolizes all the keys for all its hash items" do
      [[{"x"=>{"y"=>[{"z"=>13}]}}]]._symbolize_keys.should ==
        [[{:x=>{:y=>[:z => 13]}}]]
    end
  end

  # --- Hash ---

  context "Hash#_blank?" do
    it "behaves accordingly to hash's emptyness status" do
      {}._blank?.should == true
      {:foo => :bar}._blank?.should == false
    end
  end

  context "Hash#_stringify_keys" do
    it "stringifies all the keys" do
      {"1"=>2, :x=>[[{:y=>{:z=>13}}], 2]}._stringify_keys.should ==
        {"1"=>2, "x"=>[[{"y"=>{"z"=>13}}], 2]}
    end
  end

  context "Hash#_symbolize_keys" do
    it "symbolizes all keys" do
       {"1"=>2, "x"=>[[{"y"=>{"z"=>13}}], 2]}._symbolize_keys.should ==
        {:"1"=>2, :x=>[[{:y=>{:z=>13}}], 2]}
    end
  end

  context "Hash#_at" do
    it "fails if the given path does not not exist" do
      lambda { {}._at('x','y') }.should raise_error(StandardError)
    end
    it "does not fail if the given path does not exist but a default value is provided" do
      {}._at('x', :default => 'defval').should == 'defval'
    end
    it "calls a block if the given path does not exist and a default value is not provided" do
      ({}._at('x'){ 'defval' }).should == 'defval'
      lambda{ {}._at('x'){ fail "NotFound.MyCoolError" }}.should raise_error(RuntimeError, "NotFound.MyCoolError")
    end
    it "returns the requested value by the given path when the path exists" do
      {'x' => nil}._at('x').should == nil
      {'x' => 4}._at('x').should == 4
      {'x' => { 'y' => { 'z' => 'value'} }}._at('x', 'y', 'z').should == 'value'
    end
    it "arrayifies the result when :arrayify => true option is set" do
      {'x' => { 'y' => { 'z' => 'value'} }}._at('x', 'y', 'z', :arrayify => true).should == ['value']
    end
  end

  context "Hash#_arrayify_at" do
    it "extracts a value by the given path and arrayifies it" do
      {'x' => { 'y' => 'z' }}._arrayify_at('x', 'y').should == ['z']
      {'x' => { 'y' => ['z'] }}._arrayify_at('x', 'y').should == ['z']
    end
  end

  context "Hash#_arrayify" do
    it "wraps self into array" do
      hash = { 1 => 2}
      hash._arrayify.should == [hash]
    end
  end
end