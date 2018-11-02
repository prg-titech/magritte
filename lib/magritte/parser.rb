module Magritte
  module Parser
    include Matcher::DSL
    extend self

    class ParseError < StandardError
      def initialize(skel, msg)
        @skel = skel
        @msg = msg
      end

      attr_reader :skel
      attr_reader :msg

      def to_s
        "#{msg} at #{skel.range.repr}"
      end
    end

    def error!(skel, msg)
      raise ParseError.new(skel, msg)
    end

    def parse_root(skel)
      elems = skel.elems.map do |item|
        parse_line(item)
      end
      AST::Block[elems]
    end

    def parse_line(item)
      item.match(rsplit(~_, token(:pipe), ~_)) do |before, after|
        return AST::Pipe[parse_line(before), parse_command(after)]
      end

      # Default
      parse_command(item)
    end

    def parse_vector(vec)
      AST::Vector[parse_terms(vec)]
    end

    def parse_command(command)
      redirects = []
      matched = true
      while matched
        matched = command.match(rsplit(~_, ~any(token(:gt), token(:lt)), ~_)) do |direct, before, target|
          unless target.elems.size == 1
            error!(Skeleton::Item[[direct]+target.elems], "Redirect target must be a single term")
          end
          command = before
          redirects << AST::Redirect[direct.token?(:gt) ? :> : :<, parse_term(target.elems.first)]
        end
      end
      head, *args = parse_terms(command)
      return head if args.empty?
      AST::Command[head, args, redirects]
    end

    def parse_terms(terms)
      out = []
      elems = terms.elems.dup
      while x = elems.shift do
        if x.token?(:bang)
          raise "Parse Error" if out == []
          source = out.pop
          lookup = elems.shift
          raise "Parse Errror" if lookup.nil?
          out << AST::Access[source, parse_term(lookup)]
        else
          out << parse_term(x)
        end
      end
      return out
    end

    def parse_term(term)
      term.match(~token(:var)) do |var|
        return AST::Variable[var.value]
      end

      term.match(~token(:lex_var)) do |var|
        return AST::LexVariable[var.value]
      end

      term.match(~token(:bind)) do |var|
        return AST::Binder[var.value]
      end

      term.match(~token(:bare)) do |bare|
        return AST::String[bare.value]
      end

      term.match(nested(:lparen,~_)) do |item|
        item.match(lsplit(~_, token(:arrow), ~_)) do |before, after|
          unless before.elems.all? { |e| e.token?(:bind) }
            error!(term, "TODO: Support patterns")
          end
          patterns = before.elems.map { |e| AST::Binder[e.value] }
          return AST::Lambda["anon@#{term.range.repr}", patterns, [parse_line(after)]]
        end

        return AST::Block[item.elems.map { |e| parse_line(e) }]
      end

      term.match(nested(:lbrack,~_)) do |item|
        return parse_vector(item)
      end

      error!(term, "unrecognized syntax")
    end
  end
end
