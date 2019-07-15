require 'strscan'
require 'set'
module Magritte
  class Lexer

    class LexError < CompileError
      def initialize(location, msg)
        @location = location
        @msg = msg
      end

      attr_reader :location
      attr_reader :msg

      def to_s
        "Lexing Error: #{@msg} at #{@location.repr}"
      end
    end

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
        :eof,
        :pipe,
        :write_to,
        :read_from,
        :equal,
        :d_amp,
        :d_bar,
        :d_per,
        :d_bang,
        :d_per_bang,
        :arrow,
        :rbrace,
        :rbrack,
        :rparen
      ])

      SKIP = Set.new([
        :lparen,
        :lbrace,
        :lbrack,
        :arrow,
        :equal,
        :write_to,
        :read_from,
        :d_per,
        :d_per_bang,
        :d_amp,
        :d_bar,
        :pipe
      ])

      FREE_NL = Set.new([
        :lbrack,
      ])

      def initialize(type, value, range)
        @type = type
        @value = value
        @range = range
      end

      def continue?
        CONTINUE.include?(@type)
      end

      def skip?
        SKIP.include?(@type)
      end

      def nest?
        NESTED_PAIRS.key?(@type)
      end

      def nest_pair
        NESTED_PAIRS[@type]
      end

      def free_nl?
        FREE_NL.include?(@type)
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

    def initialize(source_name, string)
      @source_name = source_name
      @scanner = StringScanner.new(string)
      @line = 1
      @col = 0

      # p :lex => string

      skip_ws
      advance while peek.is?(:nl)
    end

    attr_reader :source_name

    def peek
      @peek ||= self.advance
    end

    def next
      # p :next
      tok = advance

      loop do
        # puts "loop: #{tok.repr} #{peek.repr}"
        if tok.is?(:nl) && peek.is?(:nl)
          # puts "CONSOLIDATE"
          advance
        elsif tok.skip? && peek.is?(:nl)
          advance while peek.is?(:nl)
          # puts "SKIP: #{tok.repr}"
          return tok
        elsif tok.is?(:nl) && peek.continue?
          out = peek
          advance
          # puts "CONTINUE: #{out.repr}"
          return out
        else
          # puts "NORMAL: #{tok.repr}"
          return tok
        end
      end
    end

    def advance
      out = advance_
      # puts "advance: #{out.repr} --- #{@match.inspect} --- #{@scanner.peek(5).inspect}"
      out
    end

    def advance_
      if @peek
        p = @peek
        @peek = nil
        return p
      end

      begin
        if @scanner.eos?
          return token(:eof)
        elsif scan /[\n;]|(#[^\n]*)/
          return token(:nl)
        elsif scan /[(]/
          return token(:lparen)
        elsif scan /[)]/
          return token(:rparen)
        elsif scan /[{]/
          return token(:lbrace)
        elsif scan /[}]/
          return token(:rbrace)
        elsif scan /\[/
          return token(:lbrack)
        elsif scan /\]/
          return token(:rbrack)
       elsif scan /\=>/
         return token(:arrow)
       elsif scan /[=]/
         return token(:equal)
       elsif scan /</
         return token(:lt)
       elsif scan />/
         return token(:gt)
       elsif scan /%%!/
         return token(:d_per_bang)
       elsif scan /%%/
         return token(:d_per)
       elsif scan /!!/
         return token(:d_bang)
       elsif scan /&&/
         return token(:d_amp)
       elsif scan /\|\|/
         return token(:d_bar)
       elsif scan /&/
         return token(:amp)
       elsif scan /\|/
         return token(:pipe)
       elsif scan /!/
         return token(:bang)
        elsif scan /[$]([\w-]+)/
          return token(:var, group(1))
        elsif scan /[%]([\w-]+)/
          return token(:lex_var, group(1))
        elsif scan /[?](\w+)/
          return token(:bind, group(1))
        elsif scan /([-]?[0-9]+([\.][0-9]*)?)/
          return token(:num, group(1))
        elsif scan /"((?:\\.|[^"])*)"/
          return token(:string, group(1))
        elsif scan /'(.*?)'/m
          return token(:string, group(1))
        elsif scan /([_.\/a-zA-Z0-9-]+)/
          return token(:bare, group(1))
        else
          error!("Unknown token near #{@scanner.peek(3).inspect}")
        end
      ensure
        skip_ws
      end
    end

    class Location
      include Comparable

      def range
        Range.new(self, self)
      end

      def initialize(source_name, source, line, col, index)
        @source_name = source_name
        @source = source
        @line = line
        @col = col
        @index = index
      end

      attr_reader :source_name
      attr_reader :source
      attr_reader :line
      attr_reader :col
      attr_reader :index

      def <=>(other)
        raise "Incomparable" unless source_name == other.source_name
        self.index <=> other.index
      end

      def repr
        "#{line}:#{col}"
      end
    end

    class Range

      def range
        self
      end

      def self.between(start, fin)
        start_loc = start.range.first
        fin_loc = fin.range.last
        if start_loc.source_name != fin_loc.source_name
          raise "Can't compute Range.between, mismatching source names: #{start_loc.source_name} != #{fin_loc.source_name}"
        end

        new(start_loc, fin_loc)
      end

      def initialize(first, last)
        @first = first
        @last = last
      end

      attr_reader :first
      attr_reader :last

      def repr
        "#{first.source_name}@#{first.repr}~#{last.repr}"
      end

      def to_s
        repr
      end
    end

    # This function is called when we have instantiated a lexer
    # and want to generate tokens of the entire program
    # This is for example used in the lexer_spec
    # when we call lex.to_a to generate the array
    # of tokens
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
      prev_pos = current_pos
      if @scanner.scan(re)
        @match = @scanner.matched
        @groups = @scanner.captures
        update_line_col(@match)
        @last_range = Range.new(prev_pos, current_pos)
        true
      else
        @match = nil
        @groups = []
        @last_range = [0, 0] # Is this really correct?
        false
      end
    end

    def current_pos
      Location.new(@source_name, @scanner.string, @line, @col, @scanner.pos)
    end

    def update_line_col(string)
      nlcount = string.scan(/\n/).size
      @line += nlcount
      if nlcount > 0
        string =~ /\n.*?\z/
        @col = $&.size
      else
        @col += string.size
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
      skip %r{
        \s*
        (
          ([#][^\n]*\n?)\s*
            |
          [\n;]\s*
        )*
        \s*
      }mx
      p :skip_lines => [@scanner.matched, @scanner.peek(5)]
    end

    def skip(re)
      @scanner.skip(re) and update_line_col(@scanner.matched)
    end

    def error!(msg)
      raise LexError.new(current_pos, msg)
    end
  end
end
