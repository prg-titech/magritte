module Magritte
  module Parser
    include Matcher::DSL
    extend self

    class ParseError < CompileError
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

    def parse(skel)
      parse_root(skel)
    end

    def parse_root(skel)
      elems = skel.sub_items.map do |item|
        parse_line(item)
      end
      AST::Block[elems]
    end

    def parse_line(item)
      item.match(starts(token(:amp), ~_)) do |body|
        return AST::Spawn[parse_line(body)]
      end

      item.match(rsplit(~_, token(:pipe), ~_)) do |before, after|
        return AST::Pipe[parse_line(before), parse_command(after)]
      end

      # Match any line that has an equal sign
      item.match(lsplit(~_, token(:equal), ~_)) do |lhs, rhs|
        # Special syntax for lambda assignment
        lhs.match(singleton(nested(:lparen, starts(~token(:bare), ~_)))) do |var, bindings|
          unless bindings.elems.all? { |elem| elem.token?(:bind) }
            error!(bindings,"Invalid pattern")
          end
          return AST::Assignment[[parse_term(var)], [parse_lambda("anon@#{item.range.repr}", bindings, rhs)]]
        end
        # Normal assignment
        unless lhs.elems.all? { |elem| elem.token?(:bare) || elem.token?(:var) || elem.token?(:lex_var) }
          error!(lhs, "Invalid lhs")
        end

        return AST::Assignment[parse_terms(lhs), parse_terms(rhs)]
      end

      # Default
      parse_command(item)
    end

    def parse_vector(vec)
      AST::Vector[parse_terms(vec)]
    end

    def parse_lambda(name, bindings, bodies)
      unless bindings.elems.all? { |e| e.token?(:bind) }
        error!(term, "TODO: Support patterns")
      end
      patterns = bindings.elems.map { |e| AST::Binder[e.value] }
      return AST::Lambda[name, patterns, [parse_line(bodies)]]
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

      command.match(singleton(nested(:lparen,~_))) do |i|
        return parse_root(i)
      end

      vec = parse_terms(command)
      AST::Command[vec, redirects]
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

      term.match(~token(:string)) do |bare|
        return AST::String[bare.value]
      end

      term.match(~token(:num)) do |num|
        return AST::Number[num.value]
      end

      term.match(nested(:lparen,~_)) do |item|
        item.match(lsplit(~_, token(:arrow), ~_)) do |before, after|
          return parse_lambda("anon@#{term.range.repr}", before, after)
        end

        return AST::Subst[item.sub_items.map { |e| parse_line(e) }]
      end

      term.match(nested(:lbrack,~_)) do |item|
        return parse_vector(item)
      end

      error!(term, "unrecognized syntax")
    end
  end
end
