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

class String

  # Constantizes the string.
  #
  # @return [Class, Module] The constantized class/module.
  #
  # @raise [NameError] If the name is not in CamelCase or is not initialized.
  #
  # @example
  #   "Module"._constantize #=> Module
  #   "Class"._constantize  #=> Class
  #
  def _constantize
    unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ self
      fail(::NameError, "#{self.inspect} is not a valid constant name!")
    end
    Object.module_eval("::#{$1}", __FILE__, __LINE__)
  end

  # Camelizes the string.
  #
  # @param [Boolean] lower_case When set to true it downcases the very first symbol of the string.
  #
  # @return [String] The camelized string value.
  #
  # @example
  #  'hello_world'._camelize       #=> 'HelloWorld'
  #  'hello_world'._camelize(true) #=> 'helloWorld'
  #  'HelloWorld'._camelize        #=> 'HelloWorld'
  #
  def _camelize(lower_case = false)
    words = self.gsub(/([A-Z])/, '_\1').
                 split(/_|\b/).
                 map{ |word| word.capitalize }.
                 reject{ |word| word == '' }
    words[0] = words[0].downcase if words[0] && lower_case
    words.join('')
  end
  alias_method :_camel_case, :_camelize

  # Underscorizes the string.
  #
  # @return [String] The camelized string value.
  #
  # @example
  #  'HelloWorld'._underscore #=> 'hello_world'
  #
  def _snake_case
    self.split(/\b/).
         map{ |word| word.gsub(/[A-Z]/){ |match| "#{$`=='' ? '' : '_'}#{match.downcase}" } }.
         join('')
  end
  alias_method :_underscore, :_snake_case

  # Wraps the string into an array.
  #
  # @return [Array]
  #
  # @example
  #   'hahaha'._arrayify #=> ['hahaha']
  #
  def _arrayify
    [ self ]
  end

  # Returns +true+ is the string has zero length or contains spaces only. And it returns +false+
  # if the string has any meaningful value.
  #
  # @return [Boolean]
  #
  def _blank?
    empty? || strip.empty?
  end
end


class Object

  # Checks if the current object is blank or empty.
  # "", "  ", nil, [] and {} are assumes as blank.
  #
  # @return [Boolean] +True+ if the object is blank and +false+ otherwise.
  #
  def _blank?
    case
    when respond_to?(:blank?) then blank?
    when respond_to?(:empty?) then empty?
    else                           !self
    end
  end

  # Checks if the object has any non-blank value (opposite to Object#_blank?)
  #
  # @return [Boolean] +True+ if the object has any meaningful value and +false+ otherwise.
  #
  def _present?
    !_blank?
  end

  # Returns a list of modules an object is extended with.
  #
  # @return [Array] A list of modules.
  #
  def _extended
    (class << self; self; end).included_modules
  end

  # Checks whether an object was extended with a module.
  #
  # @return [Boolean] +True+ if the object is extended with the given module.
  #
  def _extended?(_module)
    _extended.include?(_module)
  end

  # Wraps the object into an array.
  #
  # @return [Array]
  #
  # @example
  #   nil._arrayify  #=> []
  #   1._arrayify    #=> [1]
  #   :sym._arrayify #=> [:sym]
  #
  def _arrayify
    Array(self)
  end
end

class Array

  # Stringifies keys on all the hash items.
  #
  def _symbolize_keys
    map do |item|
      item.respond_to?(:_symbolize_keys) ? item._symbolize_keys : item
    end
  end

  # Stringifies keys on all the hash items.
  #
  def _stringify_keys
    map do |item|
      item.respond_to?(:_stringify_keys) ? item._stringify_keys : item
    end
  end
end

class Hash

  # Converts the root keys of the hash to symbols.
  #
  # @return [Hash]
  #
  def _symbolize_keys
    inject({}) do |hash, (key, value)|
      new_key = key.respond_to?(:to_sym) ? key.to_sym : key
      value   = value._symbolize_keys if value.respond_to?(:_symbolize_keys)
      hash[new_key] = value
      hash
    end
  end

  # Converts the keys of the hash to strings.
  #
  # @return [Hash]
  #
  def _stringify_keys
    inject({}) do |hash, (key, value)|
      new_key = key.to_s              if key.respond_to?(:to_s)
      value   = value._stringify_keys if value.respond_to?(:_stringify_keys)
      hash[new_key] = value
      hash
    end
  end

  # Extract a value from the hash by its path. The path is a comma-separated list of keys, staring
  # from the root key.
  #
  # @param [Array] path The path to the key. If the very last value is a hash then it is treated as
  #   a set of options.
  #
  # The options are: 
  #  - :arrayify Convert the result into Array (unless it is).
  #  - :default A value to be returned unless the requested key exist.
  #
  # @yield [] If a block is given and the key is not found then it calls the block.
  # @yieldreturn [Object]  he block may raise a custom exception or return anything. The returned
  #   value it used for the method return.
  #
  # @return [Object] Whatever value the requested key has or the default value.
  #
  # @example
  #  {}._at('x','y')                                          #=>  Item at "x"->"y" is not found or not a Hash instance (RuntimeError)
  #  {}._at('x', :default => 'defval')                        #=>  'defval'
  #  {}._at('x'){ 'defval' }                                  #=>  'defval'
  #  {}._at('x'){ fail "NotFound.MyCoolError" }               #=>  NotFound.MyCoolError (RuntimeError)
  #  {'x' => nil}._at('x')                                    #=>  nil
  #  {'x' => 4}._at('x')                                      #=>  4
  #  {'x' => { 'y' => { 'z' => 'value'} } }._at('x', 'y', 'z') #=>  'value'
  #  {'x' => { 'y' => { 'z' => 'value'} } }._at('x', 'y', 'z', :arrayify => true) #=> ['value']
  #
  def _at(*path, &block)
    path    = path.flatten
    options = path.last.is_a?(Hash) ? path.pop.dup : {}
    key     = path.shift
    (options[:path] ||= []) << key
    if key?(key)
      if path._blank?
        # We have reached the final key in the list - report it back.
        return options[:arrayify] ?  self[key]._arrayify : self[key]
      end
      return self[key]._at(path << options, &block) if self[key].is_a?(Hash)
    end
    return options[:default]  if options.key?(:default)
    return block.call         if block
    fail(StandardError.new("Item at #{options[:path].map{|i| i.inspect}.join('->')} is not found or not a Hash instance"))
  end


  # Extracts a value from the hash by its path and arrayifies it.
  #
  # @param [Array] path The path to the key. If the very last value is a hash then it is treated as
  #   a set of options.
  #
  # @return [Array] Single item array with whatever value the requested key has.
  #
  # @example
  #   {}._arrayify_at('x', 'y', 'z')                                     #=>  []
  #   { 'x' => { 'y' => { 'z' => 'value'} }}._arrayify_at('x', 'y', 'z') #=>  ['value']
  #
  #
  def _arrayify_at(*path)
    _at(path << { :arrayify => true, :default => [] })
  end

  # Wraps the hash into an array.
  #
  # @return [Array]
  #
  # @example
  #   {1 => 2}._arrayify #=> [{1 => 2}]
  #
  def _arrayify
    [ self ]
  end
end
