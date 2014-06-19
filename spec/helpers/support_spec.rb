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
      expect('MyCoolTestConstantizeClass'._constantize).to be MyCoolTestConstantizeClass
    end
    it "fails when a string points to a non-existing class/module name" do
      expect {
       'MyBadTestConstantizeClass'._constantize
      }.to raise_error(::NameError)
    end
  end

  context "String#_camelize" do
    it "camelizes a string" do
      expect('my_test_string'._camelize).to eq'MyTestString'
      expect('MyTestString'._camelize).to eq 'MyTestString'
      expect('my_test_string'._camelize(:lower_case)).to eq 'myTestString'
      expect('MyTestString'._camelize(:lower_case)).to eq 'myTestString'
      expect('Privet, how are you_doing, los_Amigos?'._camelize).to eq 'Privet, How Are YouDoing, LosAmigos?'
    end
  end

  context "String#_snake_case" do
    it "underscorizes a string" do
      expect('MyTestString'._snake_case).to eq 'my_test_string'
      expect('my_test_string'._snake_case).to eq 'my_test_string'
      expect('Privet, How Are YouDoing, LosAmigos?'._snake_case).to eq 'privet, how are you_doing, los_amigos?'
    end
  end

  context "String#_arrayify" do
    it "arrayifies into array" do
      expect(''._arrayify).to eq ['']
      expect('something'._arrayify).to eq ['something']
    end
  end

  context "String#_blank?" do
    it "returns true when it has zero size" do
      expect(''._blank?).to be true
    end
    it "returns true when it contains spaces only" do
      expect("   \n\n\n   "._blank?).to be true
    end
    it "returns false when it has anything valueble" do
      expect("something"._blank?).to be false
    end
  end

  # --- Object ---

  context "Object#_blank?" do
    it "checks if an object responds blank?" do
      object = Object.new
      expect(object).to receive(:blank?).once.and_return(true)
      expect(object).to receive(:respond_to?).with(:blank?).once.and_return(true)
      expect(object._blank?).to be true
    end
    it "checks if an object responds empty? unles it responds to blank?" do
      object = Object.new
      expect(object).to receive(:empty?).once.and_return(true)
      expect(object).to receive(:respond_to?).with(:blank?).once.and_return(false)
      expect(object).to receive(:respond_to?).with(:empty?).once.and_return(true)
      expect(object._blank?).to be true
    end
    it "returns !self unless it responds to blank? and empty?" do
      object = Object.new
      expect(object).to receive(:respond_to?).with(:blank?).once.and_return(false)
      expect(object).to receive(:respond_to?).with(:empty?).once.and_return(false)
      expect(object._blank?).to eq !object
    end
  end

  context "Object#_arrayify" do
    it "feeds self to Array()" do
      [nil, 1, :symbol].each do |object|
        expect(object._arrayify).to eq Array(object)
      end
    end
  end

  # --- NilClass ---

  context "NilClass" do
    it "always return true" do
      expect(nil._blank?).to be true
    end
  end

  # --- FalseClass ---

  context "FalseClass" do
    it "always return true" do
      expect(false._blank?).to be true
    end
  end

  # --- TrueClass ---

  context "FalseClass" do
    it "always return false" do
      expect(true._blank?).to be false
    end
  end

  # --- Array ---

  context "Array#_blank?" do
    it "behaves accordingly to array's emptyness status" do
      expect([]._blank?).to be true
      expect([1]._blank?).to be false
    end
  end

  context "Array#_stringify_keys" do
    it "stringifies all the keys for all its hash items" do
      expect([[{:x=>{:y=>[:z => 13]}}]]._stringify_keys).to eq [[{"x"=>{"y"=>[{"z"=>13}]}}]]
    end
  end

  context "Array#_stringify_keys" do
    it "symbolizes all the keys for all its hash items" do
      expect([[{"x"=>{"y"=>[{"z"=>13}]}}]]._symbolize_keys).to eq [[{:x=>{:y=>[:z => 13]}}]]
    end
  end

  # --- Hash ---

  context "Hash#_blank?" do
    it "behaves accordingly to hash's emptyness status" do
      expect({}._blank?).to be true
      expect({:foo => :bar}._blank?).to be false
    end
  end

  context "Hash#_stringify_keys" do
    it "stringifies all the keys" do
      expect({"1"=>2, :x=>[[{:y=>{:z=>13}}], 2]}._stringify_keys).to eq("1"=>2, "x"=>[[{"y"=>{"z"=>13}}], 2])
    end
  end

  context "Hash#_symbolize_keys" do
    it "symbolizes all keys" do
       expect({"1"=>2, "x"=>[[{"y"=>{"z"=>13}}], 2]}._symbolize_keys).to eq(:"1"=>2, :x=>[[{:y=>{:z=>13}}], 2])
    end
  end

  context "Hash#_at" do
    it "fails if the given path does not not exist" do
      expect { {}._at('x','y') }.to raise_error(StandardError)
    end
    it "does not fail if the given path does not exist but a default value is provided" do
      expect({}._at('x', :default => 'defval')).to eq 'defval'
    end
    it "calls a block if the given path does not exist and a default value is not provided" do
      expect({}._at('x'){ 'defval' }).to eq 'defval'
      expect{ {}._at('x'){ fail "NotFound.MyCoolError" }}.to raise_error(RuntimeError, "NotFound.MyCoolError")
    end
    it "returns the requested value by the given path when the path exists" do
      expect({'x' => nil}._at('x')).to be nil
      expect({'x' => 4}._at('x')).to eq 4
      expect({'x' => { 'y' => { 'z' => 'value'} }}._at('x', 'y', 'z')).to eq 'value'
    end
    it "arrayifies the result when :arrayify => true option is set" do
      expect({'x' => { 'y' => { 'z' => 'value'} }}._at('x', 'y', 'z', :arrayify => true)).to eq ['value']
    end
  end

  context "Hash#_arrayify_at" do
    it "extracts a value by the given path and arrayifies it" do
      expect({'x' => { 'y' => 'z' }}._arrayify_at('x', 'y')).to eq ['z']
      expect({'x' => { 'y' => ['z'] }}._arrayify_at('x', 'y')).to eq ['z']
    end
  end

  context "Hash#_arrayify" do
    it "wraps self into array" do
      hash = { 1 => 2}
      expect(hash._arrayify).to eq [hash]
    end
  end
end