module Magritte
  module Skeleton
    class Base < Tree::Node
      def inspect
        "#<Magritte::Skeleton::Base #{self.repr}>"
      end

      def match(matcher, &b)
        vars = matcher.match_vars(self)
        return false if vars.nil?
        yield(*vars)
        true
      end

      def token?(type = nil)
        false
      end

      def range
        raise "Abstract"
      end
    end

    class Token < Base
      defdata :token

      def repr
        ".#{token.repr}"
      end

      def token?(type = nil)
        if type.nil?
          return true
        else
          return token.is?(type)
        end
      end

      def value
        token.value
      end

      def range
        token.range
      end
    end

    class Nested < Base
      defdata :open
      defdata :close
      deflistrec :elems

      def repr
        "[#{open.repr}|#{elems.map(&:repr).join(" ")}|#{close.repr}]"
      end

      def range
        Lexer::Range.between(open, close)
      end
    end

    class Item < Base
      defdata :elems # Why isn't this one deflistrec?

      def repr
        "(#{elems.map(&:repr).join(" ")})"
      end

      def range
        Lexer::Range.between(elems.first, elems.last)
      end
    end

    class Root < Base
      defdata :elems # Same question as for Item class

      def repr
        "(#{elems.map(&:repr).join(" ")})"
      end

      def range
        Lexer::Range.between(elems.first, elems.last)
      end
    end

    class NestingError < StandardError
      def initialize(open, close, type)
        @open = open
        @close = close
        @type = type
      end
    end

    class Parser
      def self.parse(lexer)
        new(nil, :eof).parse(lexer)
      end

      attr_reader :open
      attr_reader :expected_close

      def initialize(open, expected_close)
        @open = open
        @expected_close = expected_close
        @items = [[]]
      end

      def parse(lexer)
        loop do # Is there any reason why we do a "loop do" instead of "lexer.each do |token|"
          token = lexer.next
          if token.eof? and @open.nil?
            return Root[items]
          elsif token.eof?
            error!(token, "Unmatched")
          elsif token.is?(expected_close)
            return Nested[self.open, token, out]
          elsif token.nest?
            y Parser.new(token, token.nest_pair).parse(lexer)
          elsif token.is?(:nl)
            # As we instantiate the parser with open = nil
            # it can happen that we try to call free_nl?
            # on a nil object....
            next if !self.open.nil? && self.open.free_nl?
            next if lexer.peek.continue?
            @items << []
          else
            y Token[token]
          end
        end
      end

    private
      def error!(token, type)
        raise NestingError.new(@open, token, type)
      end

      def y(node)
        @items.last << node
      end

      def items
        @items.select(&:any?).map { |nodes| Item[nodes] }
      end

      def out
        if @items.size == 1
          @items[0]
        else
          items
        end
      end
    end
  end
end
