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
        
        def self.parse(text, options = {})
          # Parse the xml text
          # http://libxml.rubyforge.org/rdoc/
 
          xml = if options[:encoding] == "UTF-8"
                  xml_context = ::XML::Parser::Context.string(text)
                  xml_context.encoding = ::XML::Encoding::UTF_8
                  ::XML::SaxParser.new(xml_context)
                else
                  ::XML::SaxParser::string(text)
                end
          xml.callbacks = new(options)
          xml.parse
          xml.callbacks.result
        end

        def initialize(options = {})
          @tag  = {}
          @path = []
          @options = options
        end

        def result
          @tag
        end

        # Callbacks
        
        def on_error(msg)
          raise msg
        end

        def on_start_element_ns(name, attr_hash, prefix, uri, namespaces)
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
              namespace = namespace ? "#{namespace}:" : ""
              @tag["@#{namespace}#{key}"] = value
            end
          end
          # Put namespaces
          namespaces.each do |key, value|
            @tag["@xmlns#{key ? ':'+key.to_s : ''}"] = value
          end
        end

        def on_characters(chars)
          # Ignore lines that contains white spaces only
          return if chars[/\A\s*\z/m]
          # Put Text
          if  @options[:encoding] == "UTF-8"
            # setting the encoding in context doesn't work(open issue with libxml-ruby).
            # force encode as a work around.
            # TODO remove the force encoding when issue in libxml is fixed
            chars = chars.force_encoding("UTF-8") if chars.respond_to?(:force_encoding)
          end
          (@tag['@@text'] ||= '') << chars
          chars
        end

        def on_comment(msg)
          # Put Comments
          (@tag['@@comment'] ||= '') << msg
        end

        def on_end_element_ns(name, prefix, uri)
          # Finalize tag's text
          if @tag.key?('@@text') && @tag['@@text'].empty?
            # Delete text if it is blank
            @tag.delete('@@text')
          elsif @tag.keys.count == 0
            # Set tag value to nil then the tag is blank
            @tag = nil
          elsif @tag.keys == ['@@text']
            # Set tag value to string if it has no any other data
            @tag = @tag['@@text']
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

        def on_internal_subset (name, external_id, system_id)
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