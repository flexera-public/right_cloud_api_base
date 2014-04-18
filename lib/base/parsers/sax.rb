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

require 'xml/libxml'

module RightScale

  module CloudApi
    module Parser

      class Sax

        UTF_8_STR = "UTF-8"
        TEXT_MARK = "@@text"

        def self.parse(input, options = {})
          # Parse the xml text
          # http://libxml.rubyforge.org/rdoc/
          xml_context          = ::XML::Parser::Context.string(input)
          xml_context.encoding = ::XML::Encoding::UTF_8 if options[:encoding] == UTF_8_STR
          sax_parser           = ::XML::SaxParser.new(xml_context)
          sax_parser.callbacks = new(options)
          sax_parser.parse
          sax_parser.callbacks.result
        end


        def initialize(options = {})
          @tag            = {}
          @path           = []
          @str_path       = []
          @options        = options
          @cached_strings = {}
        end


        def result
          @cached_strings.clear
          @tag
        end


        def cache_string(name)
          unless @cached_strings[name]
            name = name.freeze
            @cached_strings[name] = name 
          end
          @cached_strings[name]
        end


        # Callbacks

        def on_error(msg)
          fail msg
        end


        def on_start_element_ns(name, attr_hash, prefix, uri, namespaces)
          name = cache_string(name)
          # Push parent tag
          @path << @tag
          # Create a new tag
          if @tag[name]
            @tag[name] = [ @tag[name] ] unless @tag[name].is_a?(Array)
            @tag[name] << {}
            @tag = @tag[name].last
          else
            @tag[name] = {}
            @tag = @tag[name]
          end
          # Put attributes
          current_namespaces = Array(namespaces.keys)
          current_namespaces << nil if current_namespaces._blank?
          attr_hash.each do |key, value|
            current_namespaces.each do |namespace|
              namespace = namespace ? "#{namespace}:" : ''
              namespace_and_key = cache_string("@#{namespace}#{key}")
              @tag[namespace_and_key] = value
            end
          end
          # Put namespaces
          namespaces.each do |key, value|
            namespace       = cache_string(key ? "@xmlns:#{key}" : '@xmlns')
            @tag[namespace] = value
          end
        end


        def on_characters(chars)
          # Ignore lines that contains white spaces only
          return if chars[/\A\s*\z/m]
          # Put Text
          if  @options[:encoding] == UTF_8_STR
            # setting the encoding in context doesn't work(open issue with libxml-ruby).
            # force encode as a work around.
            # TODO remove the force encoding when issue in libxml is fixed
            chars = chars.force_encoding(UTF_8_STR) if chars.respond_to?(:force_encoding)
          end
          name = cache_string(TEXT_MARK)
          (@tag[name] ||= '') << chars
        end


        def on_comment(msg)
          # Put Comments
          name = cache_string('@@comment')
          (@tag[name] ||= '') << msg
        end


        def on_end_element_ns(name, prefix, uri)
          name = cache_string(name)
          # Finalize tag's text
          if @tag.key?(TEXT_MARK) && @tag[TEXT_MARK].empty?
            # Delete text if it is blank
            @tag.delete(TEXT_MARK)
          elsif @tag.keys.count == 0
            # Set tag value to nil then the tag is blank
            @tag = nil
          elsif @tag.keys == [TEXT_MARK]
            # Set tag value to string if it has no any other data
            @tag = @tag[TEXT_MARK]
          end
          # Make sure we saved the changes
          if @path.last[name].is_a?(Array)
            # If it is an Array then update the very last item
            @path.last[name][-1] = @tag
          else
            # Otherwise just replace the tag
            @path.last[name] = @tag
          end
          # Pop parent tag
          @tag = @path.pop
        end


        def on_start_document
        end


        def on_reference (name)
        end


        def on_processing_instruction(target, data)
        end


        def on_cdata_block(cdata)
        end


        def on_has_internal_subset()
        end


        def on_internal_subset(name, external_id, system_id)
        end


        def on_is_standalone ()
        end


        def on_has_external_subset ()
        end


        def on_external_subset (name, external_id, system_id)
        end


        def on_end_document
        end
      end
      
    end
  end
end