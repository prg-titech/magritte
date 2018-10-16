require 'strscan'
module Magritte
  class Lexer

    class Token
      attr_reader :type
      attr_reader :value
      attr_reader :range

      def initialize(type, value, range)
        @type = type
        @value = value
        @range = range
      end

      def eof?
        @type == :eof
      end

      def repr
        if @value.nil?
          "#{@type}"
        else
          "#{@type}/#{@value}"
        end
      end

      def inspect
        "#<#{self.class.name} #{self.repr}>"
      end
    end

    include Enumerable

    def initialize(string)
      @scanner = StringScanner.new(string)
      skip_lines
    end

    def next
      if @scanner.eos?
        return token(:eof)
      elsif scan /[\n#]/
        skip_lines
        return token(:nl)
      elsif scan /[(]/
        skip_lines
        return token(:lparen)
      elsif scan /[)]/
        skip_ws
        return token(:rparen)
      elsif scan /[{]/
        skip_lines
        return token(:lbrace)
      elsif scan /[}]/
        skip_ws
        return token(:rbrace)
      elsif scan /\[/
        skip_lines
        return token(:lbrack)
      elsif scan /\]/
        skip_ws
        return token(:rbrack)
      elsif scan /[$](\w+)/
        skip_ws
        binding.pry
        return token(:var, group(1))
      else
        binding.pry
        raise "Unknown token"
      end
    end

    def lex(&block)
      loop do
        token = self.next
        yield token
        break if token.eof?
      end
    end
    alias each lex

  private
    def scan(re)
      prev_pos = @scanner.pos
      if @scanner.scan(re)
        @match = @scanner.matched
        @groups = @scanner.captures
        @last_range = [prev_pos, @scanner.pos]
        true
      else
        @match = nil
        @groups = []
        @last_range = [0, 0]
        false
      end
    end

    def match
      @match
    end

    def group(index)
      @groups[index-1]
    end

    def token(type, value = nil)
      Token.new(type, value, @last_range)
    end

    def skip_ws
      skip(/[ \t]+/)
    end

    def skip_lines
      skip /((#[^\n]*)?\n[ \t]*)*[ \t]*/m
    end

    def skip(re)
      @scanner.skip(re)
    end
  end
end
