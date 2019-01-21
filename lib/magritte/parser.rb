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
      AST::Group[elems]
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
        return parse_assignment(lhs, rhs)
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

    def parse_assignment(lhs, rhs)
      # Check if lhs have parenthesis
      # In this case we're doing a special lambda assigment
      lhs.match(singleton(nested(:lparen, starts(~_, ~_)))) do |var, bindings|
        lambda_name = ""

        # If we have an access variable we need to move the bang + one more token
        # to the var
        if !var.token?(:bare) && bindings.elems.length > 1 && bindings.elems.first.token?(:bang)
          var = Skeleton::Item[[var, bindings.elems.shift, bindings.elems.shift]]
          lambda_name = var.elems[2].value
        else
          # Note: we are only encapsulating var inside an Item in this case
          # so we can call parse_terms no matter which situation we are in
          var = Skeleton::Item[[var]]
          lambda_name = var.elems[0].value
        end

        # Check all remainding bindings are actually bindings
        unless bindings.elems.all? { |elem| elem.token?(:bind) }
          error!(bindings,"Invalid pattern")
        end

        return AST::Assignment[parse_terms(var), [parse_lambda(lambda_name, bindings, rhs)]]
      end

      # Normal assignment
      unless lhs.elems.all? { |elem| elem.token?(:bare) || elem.token?(:var) || elem.token?(:lex_var) || elem.token?(:bang) }
        error!(lhs, "Invalid lhs")
      end

      return AST::Assignment[parse_terms(lhs), parse_terms(rhs)]
    end

    def parse_lambda(name, bindings, bodies)
      unless bindings.elems.all? { |e| e.token?(:bind) }
        error!(term, "TODO: Support patterns")
      end
      patterns = bindings.elems.map { |e| AST::Binder[e.value] }
      return AST::Lambda[name, [AST::VectorPattern[patterns, nil]], [parse_root(bodies)]]
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
        return with(redirects, AST::Block[parse_root(i)])
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

    def parse_pattern(pattern)
      pattern.match(~token(:string)) do |s|
        return AST::StringPattern[s.value]
      end

      pattern.match(~token(:bare)) do |b|
        if b.value == "_"
          return AST::DefaultPattern[]
        else
          return AST::StringPattern[b.value]
        end
      end

      pattern.match(~token(:bind)) do |b|
        return AST::Binder[b.value]
      end

      pattern.match(nested(:lbrack,~_)) do |vec|
        return AST::VectorPattern[vec.elems.map { |e| parse_pattern(e) }, nil]
      end

      pattern.match(nested(:lparen,~_)) do |rest|
        error!(pattern, "ill-formed rest pattern") unless rest.match(singleton(token(:bind)))
        return AST::RestPattern[AST::Binder[rest.elems[0].value]]
      end

      error!(pattern, "unrecognized pattern")
    end

    def parse_bindings(bindings)
      bindings.map do |b|
        pats = b.elems.map { |p| parse_pattern(p) }
        rest = pats.pop if pats.last.is_a?(AST::RestPattern)
        AST::VectorPattern[pats, rest]
      end
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
        # Anon lambda spanning one line
        item.match(lsplit(~_, token(:arrow), ~_)) do |before, after|
          return parse_lambda("anon@#{term.range.repr}", before, after)
        end

        # Anon lambda spanning multiple lines
        item.elems.first.match(lsplit(_, token(:arrow), _)) do
          bindings = []
          bodies = []
          name = "anon@#{term.range.repr}"
          item.elems.each do |elem|
            tmp = elem
            elem.match(lsplit(~_, token(:arrow), ~_)) do |patterns, body|
              bindings << patterns
              bodies << []
              tmp = body
            end
            tmp.match(nay(empty)) do
              bodies.last << tmp
            end
          end

          patterns = parse_bindings(bindings)
          return AST::Lambda[name, patterns, bodies.map { |body| AST::Group[body.map { |line| parse_line(line) }]}]
        end

        return AST::Subst[AST::Group[item.sub_items.map { |e| parse_line(e) }]]
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
