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
        lhs.match(singleton(nested(:lparen, starts(~any(token(:bare),token(:var)), ~_)))) do |var, bindings|
          # Determine whether we got a bare word or an access variable
          is_bare = var.token?(:bare)
          # Check that there're at least 2 elements in binding unless we have a bare word as a variable
          # These two elements should be the bang token and bare token used in an access
          unless is_bare || bindings.elems.length > 1
            error!(var,"Invalid access variable")
          end
          # Pop the bang and bare token used for access and put it in the variable
          if !is_bare
            var = Skeleton::Item[[var, bindings.elems.shift, bindings.elems.shift]]
          end
          # Check all remainding bindings are actually bindings
          unless bindings.elems.all? { |elem| elem.token?(:bind) }
            error!(bindings,"Invalid pattern")
          end
          if is_bare
            var = parse_term(var)
            return AST::Assignment[[var], [parse_lambda(var.value, bindings, rhs)]]
          else
            var = parse_terms(var)
            return AST::Assignment[var, [parse_lambda(var.first.lookup, bindings, rhs)]]
          end
        end

        # Normal assignment
        unless lhs.elems.all? { |elem| elem.token?(:bare) || elem.token?(:var) || elem.token?(:lex_var) || elem.token?(:bang) }
          error!(lhs, "Invalid lhs")
        end

        return AST::Assignment[parse_terms(lhs), parse_terms(rhs)]
      end

      # Parse double &
      item.match(lsplit(~_, token(:d_amp), ~_)) do |lhs, rhs|
        # Check for double !
        rhs.match(lsplit(~nay(token(:d_bar)), token(:d_bang), ~nay(token(:d_bar)))) do |lhs2, rhs2|
          return AST::Else[AST::And[parse_line(lhs), parse_line(lhs2)], parse_line(rhs2)]
        end
        return AST::And[parse_line(lhs), parse_line(rhs)]
      end
      # Parse double |
      item.match(lsplit(~_, token(:d_bar), ~_)) do |lhs, rhs|
        # Check for double !
        rhs.match(lsplit(~nay(token(:d_amp)), token(:d_bang), ~nay(token(:d_amp)))) do |lhs2, rhs2|
          return AST::Else[AST::Or[parse_line(lhs), parse_line(lhs2)], parse_line(rhs2)]
        end
        return AST::Or[parse_line(lhs), parse_line(rhs)]
      end
      # Parse double %%
      item.match(lsplit(~_, token(:d_per), ~_)) do |lhs, rhs|
        return AST::Compensation[parse_command(lhs), parse_command(rhs), :conditional]
      end
      # Parse double %%!
      item.match(lsplit(~_, token(:d_per_bang), ~_)) do |lhs, rhs|
        return AST::Compensation[parse_command(lhs), parse_command(rhs), :unconditional]
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
      return AST::Lambda[name, patterns, [parse_root(bodies)]]
    end

    def parse_command(command)
      redirects = []
      vec = []
      while true do
        break if command.elems.empty?

        next if command.match(starts(~any(token(:gt), token(:lt)), ~_)) do |dir, rest|
          error!(command, 'redirect at end') if rest.elems.empty?
          target, *rest = rest.elems
          direction = dir.token?(:gt) ? :> : :<
          if target.nested?(:lparen)
            error!(target, 'TODO: redir to paren')
          else
            redirects << AST::Redirect[direction, parse_term(target)]
          end

          command = Skeleton::Item[rest]
        end

        next if command.match(starts(~_, ~_)) do |head, rest|
          vec << head
          command = rest
        end
      end

      bare_command = Skeleton::Item[vec]

      bare_command.match(singleton(nested(:lparen,~_))) do |i|
        return with(redirects, parse_root(i))
      end

      vec = parse_terms(bare_command)
      with(redirects, AST::Command[vec])
    end

    def with(redirects, expr)
      return expr if redirects.empty?
      AST::With[redirects, expr]
    end

    def parse_terms(terms)
      out = []
      elems = terms.elems.dup
      while x = elems.shift do
        if x.token?(:bang)
          error!(terms, 'cannot start with a !') if out == []
          source = out.pop
          lookup = elems.shift
          error!(terms, 'cannot end with a !') if lookup.nil?
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

      term.match(nested(:lbrace, ~_)) do |item|
        return AST::Environment[parse_root(item)]
      end

      error!(term, "unrecognized syntax")
    end
  end
end
