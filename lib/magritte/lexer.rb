require 'strscan'
module Magritte
  class Lexer

    class Token
      attr_reader :type
      attr_reader :value
      attr_reader :range
      NESTED_PAIRS = {
        :lparen => :rparen,
        :lbrack => :rbrack,
        :lbrace => :rbrace,
      }
      CONTINUE = Set.new([
        :pipe,
        :write_to,
        :read_from,
        :amp_amp,
        :bar_bar,
        :per_per,
        :per_per_excl,
        :arrow,
      ])

      def initialize(type, value, range)
        @type = type
        @value = value
        @range = range
      end

      def continue?
        CONTINUE.include?(@type)
      end

      def nest?
        NESTED_PAIRS.key?(@type)
      end

      def nest_pair
        NESTED_PAIRS[@type]
      end

      def free_nl?
        false #TODO
      end

      def is?(type)
        @type == type
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

      # Object equality based on 
      # https://stackoverflow.com/questions/1931604/whats-the-right-way-to-implement-equality-in-ruby
      def ==(o)
        o.class == self.class && o.type == @type && o.value == @value
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

    def peek
      @peek ||= self.next
    end

    def next
      if @peek
        p = @peek
        @peek = nil
        return p
      end

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
     elsif scan /\=>/
       skip_ws
       return token(:arrow)
     elsif scan /[=]/
       skip_ws
       return token(:equal)
     elsif scan /</
       skip_ws
       return token(:read_from)
     elsif scan />/
       skip_ws
       return token(:write_to)
     elsif scan /%%!/
       skip_ws
       return token(:per_per_excl)
     elsif scan /%%/
       skip_ws
       return token(:per_per)
     elsif scan /!!/
       skip_ws
       return token(:excl_excl)
     elsif scan /&&/
       skip_ws
       return token(:amp_amp)
     elsif scan /\|\|/
       skip_ws
       return token(:bar_bar)
     elsif scan /&/
       skip_ws
       return token(:amp)
     elsif scan /\|/
       skip_ws
       return token(:bar)
      elsif scan /[$](\w+)/
        skip_ws
        return token(:var, group(1))
      elsif scan /[%](\w+)/
        skip_ws
        return token(:lex_var, group(1))
      elsif scan /[?](\w+)/
        skip_ws
        return token(:bind, group(1))
      elsif scan /([-]?[0-9]+([\.][0-9]*)?)/
        skip_ws
        return token(:num, group(1))
      elsif scan /"((?:\\.|[^"])*)"/
        skip_ws
        return token(:bareword, group(1))
      elsif scan /([a-zA-Z\-]+)/
        skip_ws
        return token(:bare, group(1))
      else
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
