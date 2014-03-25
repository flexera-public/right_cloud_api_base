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

describe "Utils" do
  context "RightScale::CloudApi::Utils" do

    context "self.url_encode" do
      it "uses CGI::escape to escape" do
        str = 'hahaha'
        CGI.should_receive(:escape).once.and_return(str)
        RightScale::CloudApi::Utils.url_encode(str)
      end
      it "replaces spaces with '%20'" do
        RightScale::CloudApi::Utils.url_encode('ha ha ha').should == 'ha%20ha%20ha'
      end
    end

    context "self.params_to_urn" do
      it "converts a Hash into a string" do
        RightScale::CloudApi::Utils.params_to_urn('a' => 'b', 'c' => '', 'd' => nil).should == 'a=b&c=&d'
      end
      it "auto escapes values" do
        RightScale::CloudApi::Utils.params_to_urn('a' => 'ha  ha').should == 'a=ha%20%20ha'
      end
      it "uses a provided block to escape values" do
        RightScale::CloudApi::Utils.params_to_urn('a' => 'ha  ha'){|val| val.gsub(' ','-') }.should == 'a=ha--ha'
      end
    end

    context "self.join_urn" do
      it "joins pathes" do
        RightScale::CloudApi::Utils.join_urn('/first', 'second', 'third').should == '/first/second/third'
      end
      it "knows how to deal with empty pathes or slashes" do
        RightScale::CloudApi::Utils.join_urn('/first', '', '1/', '1.1/', 'second', 'third').should == '/first/1/1.1/second/third'
      end
      it "drops strips left when it sees a path starting with forward slash (root sign)" do
        RightScale::CloudApi::Utils.join_urn('/first', '', '1/', '1.1/', '/second', 'third').should == '/second/third'
      end
      it "adds URL params" do
        RightScale::CloudApi::Utils.join_urn('/first','second', {'a' => 'b', 'c' => '', 'd' => nil}).should == "/first/second?a=b&c=&d"
      end

      context "self.extract_url_params" do
      end

      context "self.pattern_matches?" do
        it "returns a blank Hash when there are no any params in the provided URL" do
          RightScale::CloudApi::Utils.extract_url_params('https://ec2.amazonaws.com').should == {}
        end
        it "returns parsed URL params when they are in the provided URL" do
          RightScale::CloudApi::Utils.extract_url_params('https://ec2.amazonaws.com/?w=1&x=3&y&z').should ==
            {"z"=>nil, "y"=>nil, "x"=>"3", "w"=>"1"}
        end
      end

      context "self.contentify_body" do
        before(:each) do
          @body = { '1' => '2' }
        end
        it "returns JSON when content type says it should be json" do
          RightScale::CloudApi::Utils.contentify_body(@body,'json').should == '{"1":"2"}'
        end
        it "returns XML when content type says it should be json" do
          RightScale::CloudApi::Utils.contentify_body(@body,'xml').should == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<1>2</1>" 
        end
        it "fails if there is an unsupported content-type" do
          lambda { RightScale::CloudApi::Utils.contentify_body(@body,'unsupported-smething') }.should raise_error(RightScale::CloudApi::Error)
        end
      end

      context "self.generate_token" do
        context "UUID" do
          before(:each) do
            UUID         = double('UUID', :new => double(:generate => @expectation))
            @expectation = 'something-random-from-UUID.generate'
          end
          it "uses UUID when UUID is loaded" do
            RightScale::CloudApi::Utils.generate_token == @expectation
          end
        end

        context "self.random" do
          before(:each) do
            UUID         = '' unless defined?(UUID)
            @expectation = 'something-random-from-self.random'
            UUID.should_receive(:respond_to?).with(:new).and_return(false)
          end
        it "uses self.random when UUID is not loaded" do
          RightScale::CloudApi::Utils.should_receive(:random).and_return(@expectation)
          RightScale::CloudApi::Utils.generate_token == @expectation
        end
        end
      end

      context "self.random" do
        it "generates a single random HEX digit by default" do
          RightScale::CloudApi::Utils.random[/^[0-9a-f]{1}$/].should_not be(nil)
        end
        it "generates 'size' random HEX digits when size is set" do
          RightScale::CloudApi::Utils.random(13)[/^[0-9a-f]{13}$/].should_not be(nil)
        end
        it "generates random decimal digits when :base is 10" do
          RightScale::CloudApi::Utils.random(13, :base => 10)[/^[0-9]{13}$/].should_not be(nil)
        end
        it "generates random alpha symbols when :base is 26 and :offset is 10" do
          RightScale::CloudApi::Utils.random(13, :base => 26, :offset => 10)[/^[a-z]{13}$/].should_not be(nil)
        end
      end

      context "self.arrayify" do
        it "does not change Array instances" do
          RightScale::CloudApi::Utils.arrayify([]).should == []
          RightScale::CloudApi::Utils.arrayify([1,2,3]).should ==[1,2,3]
        end
        it "wraps all the other objects into Array" do
          RightScale::CloudApi::Utils.arrayify(nil).should == [nil]
          RightScale::CloudApi::Utils.arrayify(1).should == [1]
          RightScale::CloudApi::Utils.arrayify('something').should == ['something']
          RightScale::CloudApi::Utils.arrayify({1=>2}).should == [{1=>2}]
        end
      end

      context "self.dearrayify" do
        it "returns input if the input is not an Array instance" do
          RightScale::CloudApi::Utils.dearrayify(nil).should be(nil)
          RightScale::CloudApi::Utils.dearrayify(1).should == 1
          RightScale::CloudApi::Utils.dearrayify('something').should == 'something'
          RightScale::CloudApi::Utils.dearrayify({1=>2}).should == {1=>2}
        end
        it "returns the first element of the input if the input is an Array instance" do
          RightScale::CloudApi::Utils.dearrayify([]).should be(nil)
          RightScale::CloudApi::Utils.dearrayify([1]).should be(1)
          RightScale::CloudApi::Utils.dearrayify([1,2,3]).should be(1)
        end
      end

      context "self.get_xml_parser_class" do
        it "returns RightScale::CloudApiParser::Sax by default" do
          RightScale::CloudApi::Utils.get_xml_parser_class(nil).should == RightScale::CloudApi::Parser::Sax
        end
        it "returns RightScale::CloudApiParser::Sax by its name" do
          RightScale::CloudApi::Utils.get_xml_parser_class('sax').should == RightScale::CloudApi::Parser::Sax
        end
        it "returns RightScale::CloudApiParser::ReXml by its name" do
          RightScale::CloudApi::Utils.get_xml_parser_class('rexml').should == RightScale::CloudApi::Parser::ReXml
        end
        it "fails when an unknown parser is requested" do
          lambda { RightScale::CloudApi::Utils.get_xml_parser_class('something-unknown') }.should raise_error(RightScale::CloudApi::Error)
        end
      end

      context "self.inheritance_chain" do
      end

    end
  end
end