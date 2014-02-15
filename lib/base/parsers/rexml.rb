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

require "rexml/document"

module RightScale
  module CloudApi
    module Parser

      class ReXml
        def self.parse(body, options = {})
          parse_rexml_node ::REXML::Document::new(body).root
        end
        
        def self.parse_rexml_node(node)
          attributes = {}
          children   = {}
          text       = ''

          # Parse Attributes  
          node.attributes.each do |name, value|
            attributes["@#{name}"] = value
          end

          # Parse child nodes
          node.each_element do |child|
            if child.has_elements? || child.has_text?
              response = parse_rexml_node(child)
              unless children["#{child.name}"]
                # This is a first child - keep it as is
                children["#{child.name}"] = response
              else
                # This is a second+ child: make sure we put them in an Array
                children["#{child.name}"]  = [ children["#{child.name}"] ] unless children["#{child.name}"].is_a?(Array)
                children["#{child.name}"] << response
              end
            else
              # Don't lose blank elements
              children["#{child.name}"] = nil
            end
          end

          # Parse Text
          text << node.texts.join('')

          # Merge results
          if attributes._blank? && children._blank?
            result = text._blank? ? nil : text
          else
            result = attributes.merge(children)
            result.merge!("@@text" => text) unless text._blank?
          end

          # Build a root key when necessary
          result = { node.name => result } if node.parent.is_a?(REXML::Document)

          result
        end        

      end
    end
  end
end