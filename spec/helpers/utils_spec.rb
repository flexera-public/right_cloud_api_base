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
        expect(CGI).to receive(:escape).once.and_return(str)
        RightScale::CloudApi::Utils.url_encode(str)
      end
      it "replaces spaces with '%20'" do
        expect(RightScale::CloudApi::Utils.url_encode('ha ha ha')).to eq 'ha%20ha%20ha'
      end
    end

    context "self.params_to_urn" do
      it "converts a Hash into a string" do
        expect(RightScale::CloudApi::Utils.params_to_urn('a' => 'b', 'c' => '', 'd' => nil)).to eq 'a=b&c=&d'
      end
      it "auto escapes values" do
        expect(RightScale::CloudApi::Utils.params_to_urn('a' => 'ha  ha')).to eq 'a=ha%20%20ha'
      end
      it "uses a provided block to escape values" do
        expect(RightScale::CloudApi::Utils.params_to_urn('a' => 'ha  ha'){|val| val.gsub(' ','-') }).to eq 'a=ha--ha'
      end
    end

    context "self.join_urn" do
      it "joins pathes" do
        expect(RightScale::CloudApi::Utils.join_urn('/first', 'second', 'third')).to eq '/first/second/third'
      end
      it "knows how to deal with empty pathes or slashes" do
        expect(RightScale::CloudApi::Utils.join_urn('/first', '', '1/', '1.1/', 'second', 'third')).to eq '/first/1/1.1/second/third'
      end
      it "drops strips left when it sees a path starting with forward slash (root sign)" do
        expect(RightScale::CloudApi::Utils.join_urn('/first', '', '1/', '1.1/', '/second', 'third')).to eq '/second/third'
      end
      it "adds URL params" do
        expect(RightScale::CloudApi::Utils.join_urn('/first','second', {'a' => 'b', 'c' => '', 'd' => nil})).to eq "/first/second?a=b&c=&d"
      end

      context "self.extract_url_params" do
      end

      context "self.pattern_matches?" do
        it "returns a blank Hash when there are no any params in the provided URL" do
          expect(RightScale::CloudApi::Utils.extract_url_params('https://ec2.amazonaws.com')).to eq({})
        end
        it "returns parsed URL params when they are in the provided URL" do
          expect(RightScale::CloudApi::Utils.extract_url_params('https://ec2.amazonaws.com/?w=1&x=3&y&z')).to eq(
            {"z"=>nil, "y"=>nil, "x"=>"3", "w"=>"1"}
          )
        end
      end

      context "self.contentify_body" do
        before(:each) do
          @body = { '1' => '2' }
        end
        it "returns JSON when content type says it should be json" do
          expect(RightScale::CloudApi::Utils.contentify_body(@body,'json')).to eq '{"1":"2"}'
        end
        it "returns XML when content type says it should be json" do
          expect(RightScale::CloudApi::Utils.contentify_body(@body,'xml')).to eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<1>2</1>" 
        end
        it "fails if there is an unsupported content-type" do
          expect { RightScale::CloudApi::Utils.contentify_body(@body,'unsupported-smething') }.to raise_error(RightScale::CloudApi::Error)
        end
      end

      context "self.generate_token" do
        context "UUID" do
          before(:each) do
            @expectation = 'something-random-from-UUID.generate'
            UUID         = double('UUID', :new => double(:generate => @expectation))
          end
          it "uses UUID when UUID is loaded" do
            RightScale::CloudApi::Utils.generate_token == @expectation
          end
        end

        context "self.random" do
          before(:each) do
            @expectation = 'something-random-from-self.random'
            UUID         = double('UUID', :new => double(:generate => @expectation))
            expect(UUID).to receive(:respond_to?).with(:new).and_return(false)
          end
        it "uses self.random when UUID is not loaded" do
          expect(RightScale::CloudApi::Utils).to receive(:random).and_return(@expectation)
          RightScale::CloudApi::Utils.generate_token == @expectation
        end
        end
      end

      context "self.random" do
        it "generates a single random HEX digit by default" do
          expect(RightScale::CloudApi::Utils.random[/^[0-9a-f]{1}$/]).to_not be(nil)
        end
        it "generates 'size' random HEX digits when size is set" do
          expect(RightScale::CloudApi::Utils.random(13)[/^[0-9a-f]{13}$/]).to_not be(nil)
        end
        it "generates random decimal digits when :base is 10" do
          expect(RightScale::CloudApi::Utils.random(13, :base => 10)[/^[0-9]{13}$/]).to_not be(nil)
        end
        it "generates random alpha symbols when :base is 26 and :offset is 10" do
          expect(RightScale::CloudApi::Utils.random(13, :base => 26, :offset => 10)[/^[a-z]{13}$/]).to_not be(nil)
        end
      end

      context "self.arrayify" do
        it "does not change Array instances" do
          expect(RightScale::CloudApi::Utils.arrayify([])).to eq []
          expect(RightScale::CloudApi::Utils.arrayify([1,2,3])).to eq([1,2,3])
        end
        it "wraps all the other objects into Array" do
          expect(RightScale::CloudApi::Utils.arrayify(nil)).to eq [nil]
          expect(RightScale::CloudApi::Utils.arrayify(1)).to eq [1]
          expect(RightScale::CloudApi::Utils.arrayify('something')).to eq ['something']
          expect(RightScale::CloudApi::Utils.arrayify({1=>2})).to eq( [{1=>2}])
        end
      end

      context "self.dearrayify" do
        it "returns input if the input is not an Array instance" do
          expect(RightScale::CloudApi::Utils.dearrayify(nil)).to be(nil)
          expect(RightScale::CloudApi::Utils.dearrayify(1)).to eq 1
          expect(RightScale::CloudApi::Utils.dearrayify('something')).to eq 'something'
          expect(RightScale::CloudApi::Utils.dearrayify({1=>2})).to eq({1=>2})
        end
        it "returns the first element of the input if the input is an Array instance" do
          expect(RightScale::CloudApi::Utils.dearrayify([])).to be(nil)
          expect(RightScale::CloudApi::Utils.dearrayify([1])).to eq 1
          expect(RightScale::CloudApi::Utils.dearrayify([1,2,3])).to eq 1
        end
      end

      context "self.get_xml_parser_class" do
        it "returns RightScale::CloudApiParser::Sax by default" do
          expect(RightScale::CloudApi::Utils.get_xml_parser_class(nil)).to eq RightScale::CloudApi::Parser::Sax
        end
        it "returns RightScale::CloudApiParser::Sax by its name" do
          expect(RightScale::CloudApi::Utils.get_xml_parser_class('sax')).to eq RightScale::CloudApi::Parser::Sax
        end
        it "returns RightScale::CloudApiParser::ReXml by its name" do
          expect(RightScale::CloudApi::Utils.get_xml_parser_class('rexml')).to eq RightScale::CloudApi::Parser::ReXml
        end
        it "fails when an unknown parser is requested" do
          expect { RightScale::CloudApi::Utils.get_xml_parser_class('something-unknown') }.to raise_error(RightScale::CloudApi::Error)
        end
      end

      context "self.inheritance_chain" do
      end

    end
  end
end