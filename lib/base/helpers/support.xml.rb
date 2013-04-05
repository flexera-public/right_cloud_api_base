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

class Object #:nodoc:

  RIGHTXMLSUPPORT_XMLESCAPE   = {'"' => '&quot;', '\'' =>'&apos;', '<' => '&lt;', '>' => '&gt;'}
  RIGHTXMLSUPPORT_XMLUNESCAPE = RIGHTXMLSUPPORT_XMLESCAPE.invert
  RIGHTXMLSUPPORT_XMLINDENT   = ""
  RIGHTXMLSUPPORT_XMLLEVEL    = 0
  RIGHTXMLSUPPORT_XMLCRLF     = "\n"

  # Escapes non-XML symbols.
  #
  # @return [String] XML-escaped string.
  #
  # @example
  #   "Hello <'world'> & \"the Universe\""._xml_escape #=>
  #     "Hello &lt;&apos;world&apos;&gt; &amp; &quot;the Universe&quot;"
  #
  def _xml_escape
    self.to_s.gsub('&', '&amp;').gsub(/#{RIGHTXMLSUPPORT_XMLESCAPE.keys.join('|')}/) { |match| RIGHTXMLSUPPORT_XMLESCAPE[match] }
  end

  
  # Conditionally escapes non-XML symbols.
  #
  # @param [Hash] opts A set of options.
  # @option opts [Boolean] :escape The flag.
  #
  # @return [String] XML-escaped string if :escape it set ot true or self otherwise.
  #
  def _xml_conditional_escape(opts={})
    opts[:escape] ? self._xml_escape : self.to_s
  end

  # Unescapes XML-escaped symbols.
  #
  # @return [String] XML-unscaped string.
  #
  # @example
  #   "Hello &lt;&apos;world&apos;&gt; &amp; &quot;the Universe&quot;"._xml_unescape #=>
  #     "Hello <'world'> & \"the Universe\"
  #
  def _xml_unescape
    self.to_s.gsub(/#{RIGHTXMLSUPPORT_XMLUNESCAPE.keys.join('|')}/) { |match| RIGHTXMLSUPPORT_XMLUNESCAPE[match] }.gsub('&amp;','&')
  end

  # Fixes the given set of options.
  #
  def _xml_get_opts(opts={}) # :nodoc:
    opts[:level]  ||= RIGHTXMLSUPPORT_XMLLEVEL
    opts[:indent] ||= RIGHTXMLSUPPORT_XMLINDENT
    opts[:crlf]   ||= opts[:indent].empty? ? "" : RIGHTXMLSUPPORT_XMLCRLF
    opts
  end

  # Returns an aligned piece of XML text.
  #
  def _xml_align(opts={}) # :nodoc:
    return '' if self.to_s.empty?
    opts = _xml_get_opts(opts)
    "#{opts[:indent]*opts[:level]}#{self}#{opts[:crlf]}"
  end


  # Returns an XML-representation of the object.
  #
  # @param [Hash] opts A set of options.
  # @option opts [Boolean] :escape The flag.
  #
  # @return [String] The result is an XML-escaped string (if :escape flag is set) or self otherwise.
  #
  def _to_xml(opts={})
    _xml_conditional_escape(_xml_get_opts(opts))
  end

  # Returns an XML-representation of the object starting with '<?xml version="1.0" encoding="UTF-8"?>'
  # string.
  #
  # @param [Hash] args A set of arguments (see _to_xml)
  #
  # @return [String]
  #
  def _to_xml!(*args)
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"+
    "#{_to_xml(*args)}"
  end
end

# --- Array ---

class Array #:nodoc:

  # Returns an XML-representation if the array object.
  #
  # @param [Hash] opts A set of options.
  # @option opts [Boolean] :escape The flag.
  # @option opts [String] :tag The tag every array item is to be wrapped with ('<item>' by default)
  #
  # @return [String]
  #
  # @example
  #   [1,2,3,4]._to_xml #=>
  #     '<item>1</item><item>2</item><item>3</item><item>4</item>'
  #
  # @example
  #   [1,2,3,4]._to_xml(:crlf => "\n") #=>
  #      <item>1</item>
  #      <item>2</item>
  #      <item>3</item>
  #      <item>4</item>
  #
  # @example
  #   [1,2,[3,4,[5]]]._to_xml(:indent => '  ', :tag => 'hoho') #=>
  #      <hoho>1</hoho>
  #      <hoho>2</hoho>
  #      <hoho>
  #        <item>3</item>
  #        <item>4</item>
  #        <item>
  #          <item>5</item>
  #        </item>
  #      </hoho>
  #
  def _to_xml(opts={})
    opts = _xml_get_opts(opts)
    tag  = opts.delete(:tag) || 'item'
    { tag => self }._to_xml(opts)
  end
end

class Hash #:nodoc:
  RIGHTXMLSUPPORT_SORTORDERREGEXP = /(\{#(\d+)\})$/

  # Generate a consecutive id for a new key.
  # If String or Symbol is passed then adds the id to it.
  #
  # The method is widely used for MS Azure XMLs because MS requires XML
  # tags to appear in a predefined order. Grrr... ;)
  #
  # @param [String] key_name Usually a tag name.
  #
  # @return [String] A string containing the original one and the current ordering ID.
  #   if key_name was not set then it returns the next id value.
  #
  # @example
  #   Hash::_order('hahaha') #=> "hahaha{#1}"
  #   Hash::_order('hohoho') #=> "hohoho{#2}"
  #   Hash::_order           #=> 3
  #
  # @example
  #   hash = {
  #     Hash::_order('foo') => 34,
  #     Hash::_order('boo') => 45,
  #       Hash::_order('zoo') => 53,
  #       Hash::_order('poo') => 10,
  #       Hash::_order('moo') => {
  #       Hash::_order('noo') => 101,
  #       Hash::_order('too') => 113,
  #       Hash::_order('koo') => 102,
  #     },
  #     Hash::_order('woo') => 03,
  #     Hash::_order('hoo') => 1
  #   }
  #   hash._to_xml(:indent => '  ') #=>
  #      <boo>45</boo>
  #      <zoo>53</zoo>
  #      <poo>10</poo>
  #      <moo>
  #      <noo>101</noo>
  #        <too>113</too>
  #        <koo>102</koo>
  #      </moo>
  #      <woo>3</woo>
  #      <hoo>1</hoo>
  #
  def self._order(key_name=nil)
    @_next_ordered_key_id ||= 0
    @_next_ordered_key_id  += 1
    if key_name
      fail(RuntimeError.new('String or Symbol is expected')) unless key_name.is_a?(String) || key_name.is_a?(Symbol)
      result = "#{key_name}{##{@_next_ordered_key_id}}"
      result = result.to_sym if key_name.is_a?(Symbol)
      result
    else
      @_next_ordered_key_id
    end
  end

  # Sorts the keys accordingly to their order definition (if Hash::_order was used).
  def _xml_sort_keys # :nodoc:
    keys.sort do |key1, key2|
      key1idx = key1.to_s[RIGHTXMLSUPPORT_SORTORDERREGEXP] && $2 && $2.to_i
      key2idx = key2.to_s[RIGHTXMLSUPPORT_SORTORDERREGEXP] && $2 && $2.to_i
      if    key1idx && key2idx then key1idx <=> key2idx
      elsif key1idx            then -1
      elsif key2idx            then  1
      else                           0
      end
    end
  end

  # Builds the final XML tag text.
  def _xml_finalize_tag(tag_name, tag_attributes, tag_text, tag_elements, opts) # :nodoc:
    next_opts = opts.merge(:level => opts[:level] + 1)
    case
    when tag_elements.empty? && tag_text.empty? then "<#{tag_name}#{tag_attributes}/>"._xml_align(opts)
    when tag_elements.empty?                    then "<#{tag_name}#{tag_attributes}>#{tag_text}</#{tag_name}>"._xml_align(opts)
    else                                             "<#{tag_name}#{tag_attributes}>"._xml_align(opts) +
                                                     tag_text._xml_align(next_opts)                    +
                                                     tag_elements                                     +
                                                     "</#{tag_name}>"._xml_align(opts)
    end
  end

  # Returns an XML-representation if the hash object.
  #
  # @param [Hash] opts A set of options.
  # @option opts [Boolean] :escape The flag.
  # @option opts [Boolean] :indent The indentation string (is blank by default).
  # @option opts [Boolean] :crfl   The CR/LF string (is blank by default).
  #
  # @return [String]
  #
  # @example
  #   ({ 'a' => [ 1, { :c => 'd' } ] })._to_xml #=>
  #     "<a>1</a><a><c>d</c></a>"
  #
  # @example
  #   { 'screen' => {
  #       '@width' => 1080,
  #       '@hight' => 720,
  #       '@@text' => 'HD',
  #       'color'  => {
  #         '@max-colors' => 65535,
  #         '@dinamic-resolution' => '1:1000000',
  #         '@@text' => '<"PAL">',
  #           'brightness' => {
  #             'bright' => true
  #           }
  #         }
  #       }
  #     }._to_xml(:indent => '  ',
  #               :escape => true) #=>
  #        <screen width="1080" hight="720">
  #          HD
  #          <color max-colors="65535" dinamic-resolution="1:1000000">
  #            &lt;&quot;PAL&quot;&gt;
  #            <brightness>
  #              <bright>true</bright>
  #            </brightness>
  #          </color>
  #        </screen>
  #
  def _to_xml(opts={})
    result    = ''
    opts      = _xml_get_opts(opts)
    next_opts = opts.merge(:level => opts[:level] + 1)
    _xml_sort_keys.each do |tag_name|
      value    = self[tag_name]
      tag_name = tag_name.to_s.sub(RIGHTXMLSUPPORT_SORTORDERREGEXP, '')
      if value.is_a?(Hash)
        tag_attributes = ''; tag_elements = ''; tag_text = ''
        value._xml_sort_keys.each do |item|
          item_value = value[item]
          item       = item.to_s.sub(RIGHTXMLSUPPORT_SORTORDERREGEXP, '')
          case
          when item == '@@text' then tag_text       << item_value._xml_conditional_escape(opts)
          when item[/^@[^@]/]   then tag_attributes << %Q{ #{item[1..-1]}="#{item_value._xml_conditional_escape(opts)}"}
          else                       tag_elements   << { item => item_value }._to_xml(next_opts)
          end
        end
        result << _xml_finalize_tag(tag_name, tag_attributes, tag_text, tag_elements, opts)
      else
        value = [value] unless value.is_a?(Array)
        value.each do |item|
          tag_attributes = ''; tag_elements = ''; tag_text = ''
          if item.is_a?(Hash) || item.is_a?(Array) then tag_elements = item._to_xml(next_opts)
          else                                          tag_text     = item._xml_conditional_escape(opts)
          end
          result << _xml_finalize_tag(tag_name, tag_attributes, tag_text, tag_elements, opts)
        end
      end
    end
    result
  end

end