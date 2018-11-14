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

    def initialize(source_name, string)
      @source_name = source_name
      @scanner = StringScanner.new(string)
      @line = 0
      @col = 0
      skip_lines
    end

    attr_reader :source_name

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
      elsif scan /[\n;]|(#[^\n]*)/
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
       return token(:lt)
     elsif scan />/
       skip_ws
       return token(:gt)
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
       return token(:pipe)
     elsif scan /!/
       skip_ws
       return token(:bang)
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
        return token(:string, group(1))
      elsif scan /'(.*?)'/m
        skip_ws
        return token(:string, group(1))
      elsif scan /([a-zA-Z\-0-9]+)/
        skip_ws
        return token(:bare, group(1))
      else
        error!("Unknown token near #{@scanner.peek(3)}")
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
      skip /((#[^\n]*)?\n[ \t;]*)*[ \t;]*/m
    end

    def skip(re)
      @scanner.skip(re) and update_line_col(@scanner.matched)
    end

    def error!(msg)
      raise LexError.new(current_pos, msg)
    end
  end
end
