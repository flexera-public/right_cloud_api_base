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

describe "support_xml.rb" do

  # --- Object ---

  context "Object#_xml_escale" do
    it "escapes non-xml symbols" do
      expect("Hello <'world'> & \"the Universe\""._xml_escape).to eq(
        "Hello &lt;&apos;world&apos;&gt; &amp; &quot;the Universe&quot;"
      )
    end
  end

  context "Object#_xml_unescale" do
    it "unescapes non-xml symbols" do
      expect("Hello &lt;&apos;world&apos;&gt; &amp; &quot;the Universe&quot;"._xml_unescape).to eq(
        "Hello <'world'> & \"the Universe\""
      )
    end
  end

  context "Object#_to_xml" do
    it "returns a simple XML string" do
      expect("hahaha"._to_xml).to eq 'hahaha'
    end
  end

  # --- Array ---

  context "Aray#_to_xml" do
    it "builds a one-line XML by default" do
      expect(['a', 2, [3, 4], 'string', :symbol, { 3 => 4 }, { 5 => { '@i:type' => '13', '@@text' => 555 }}].\
        _to_xml).to eq(
          "<item>a</item><item>2</item><item><item>3</item><item>4</item></item>" +
          "<item>string</item><item>symbol</item><item><3>4</3></item><item><5 i:type=\"13\">555</5></item>"
        )
    end
    it "builds a multi-line XML when :indent is set" do
      expect(['a', 2, [3, 4], 'string', :symbol,
       { 3 => 4 }, { 5 => { '@i:type' => '13', '@@text' => 555 }}]._to_xml(:tag => 'item', :indent => '  ')).to eq(
        "<item>a</item>\n"      +
        "<item>2</item>\n"      +
        "<item>\n"              +
        "  <item>3</item>\n"    +
        "  <item>4</item>\n"    +
        "</item>\n"             +
        "<item>string</item>\n" +
        "<item>symbol</item>\n" +
        "<item>\n"              +
        "  <3>4</3>\n"          +
        "</item>\n"             +
        "<item>\n"              +
        "  <5 i:type=\"13\">555</5>\n" +
        "</item>\n"
      )
    end
  end

  # --- Hash ---

  context "Hash#_to_xml" do

    it "builds a simple XML from a single key hash" do
      expect(({ 'a' => [ 1, { :c => 'd' } ] })._to_xml).to eq "<a>1</a><a><c>d</c></a>"
    end

    it "understands attributes as keys starting with @ and text defined as @@text" do
      expect({ 'screen' => { '@width' => 1080, '@@text' => 'HD' } }._to_xml).to eq(
        "<screen width=\"1080\">HD</screen>"
      )
    end

    # Ruby 1.8 keeps hash keys in unpredictable order and the order on the tags
    # in the resulting XMl is also not easy to predict.
    if RUBY_VERSION >= '1.9'

      it "builds a one-line hash by default" do
        expect({ 'a' => 2, :b => [1, 3, 4, { :c => { 'd' => 'something' } } ], 5 => { '@i:type' => '13', '@@text' => 555 } }._to_xml).to eq(
          '<a>2</a><b>1</b><b>3</b><b>4</b><b><c><d>something</d></c></b><5 i:type="13">555</5>'
        )
      end
      it "builds a multi-line hash when :indent is set" do
        expect({ 'a' => 2, :b => [1, 3, 4, { :c => { 'd' => 'something' } } ] }._to_xml(:indent => '  ')).to eq(
            "<a>2</a>"             + "\n" +
            "<b>1</b>"             + "\n" +
            "<b>3</b>"             + "\n" +
            "<b>4</b>"             + "\n" +
            "<b>"                  + "\n" +
            "  <c>"                + "\n" +
            "    <d>something</d>" + "\n" +
            "  </c>"               + "\n" +
            "</b>"                 + "\n"
          )
      end

      it "understands attributes as keys starting with @ and text defined as @@text (more complex "+
         "example for ruby 1.9)" do
        expect({ 'screen' => {
            '@width' => 1080,
            '@hight' => 720,
            '@@text' => 'HD',
            'color'  => {
              '@max-colors' => 65535,
              '@dinamic-resolution' => '1:1000000',
              '@@text' => '<"PAL">',
                'brightness' => {
                  'bright' => true
                }
              }
            }
          }._to_xml(:indent => '  ', :escape => true)).to eq(
              "<screen width=\"1080\" hight=\"720\">"                           + "\n" +
              "  HD"                                                            + "\n" +
              "  <color max-colors=\"65535\" dinamic-resolution=\"1:1000000\">" + "\n" +
              "    &lt;&quot;PAL&quot;&gt;"                                     + "\n" +
              "    <brightness>"                                                + "\n" +
              "      <bright>true</bright>"                                     + "\n" +
              "    </brightness>"                                               + "\n" +
              "  </color>"                                                      + "\n" +
              "</screen>"                                                       + "\n"
            )
      end

    end

    it "can mix ordering ID into Strings" do
      key1 = Hash::_order('my-item')
      key2 = Hash::_order('my-item')

      expect(!!key1[Hash::RIGHTXMLSUPPORT_SORTORDERREGEXP]).to be true
      expect(!!key2[Hash::RIGHTXMLSUPPORT_SORTORDERREGEXP]).to be true

      expect(key1).to be < key2
    end

    it "XML-text has all the keys sorted accordingly to the given order" do
      Hash::instance_variable_set('@_next_ordered_key_id', 0)
      hash = {
        Hash::_order('foo') => 34,
        Hash::_order('boo') => 45,
        Hash::_order('zoo') => 53,
        Hash::_order('poo') => 10,
        Hash::_order('moo') => {
          Hash::_order('noo') => 101,
          Hash::_order('too') => 113,
          Hash::_order('koo') => 102,
        },
        Hash::_order('woo') => 03,
        Hash::_order('hoo') => 1
       }

       expect(hash).to eq(
         "foo{#1}" => 34,
         "boo{#2}" => 45,
         "zoo{#3}" => 53,
         "poo{#4}" => 10,
         "moo{#5}" => {
           "noo{#6}" => 101,
           "too{#7}" => 113,
           "koo{#8}" => 102,
         },
         "woo{#9}" => 3,
         "hoo{#10}" => 1
       )

      expect(hash._to_xml(:indent => '  ')).to eq(
          "<foo>34</foo>"    + "\n" +
          "<boo>45</boo>"    + "\n" +
          "<zoo>53</zoo>"    + "\n" +
          "<poo>10</poo>"    + "\n" +
          "<moo>"            + "\n" +
          "  <noo>101</noo>" + "\n" +
          "  <too>113</too>" + "\n" +
          "  <koo>102</koo>" + "\n" +
          "</moo>"           + "\n" +
          "<woo>3</woo>"     + "\n" +
          "<hoo>1</hoo>"     + "\n"
        )
    end

  end

end