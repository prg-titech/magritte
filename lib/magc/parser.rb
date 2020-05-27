module Magritte
  class Parser
    include Matcher::DSL

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

    def self.parse(skel, *a)
      new(*a).parse(skel)
    end

    def initialize
      @allow_intrinsics = true # TODO default this to false
    end

    def parse(skel)
      parse_root(skel)
    end

    def parse_root(skel)
      elems = []
      sub_items = skel.sub_items.dup
      while sub_items.any?
        item = sub_items.shift

        item.match(singleton(~token(:keyword))) do |kw|
          case kw.value
          when 'allow-intrinsics'
            @allow_intrinsics = true
          when 'disallow-intrinsics'
            @allow_intrinsics = false
          else
            error!(kw, 'unknown keyword')
          end
        end and next

        match_funcdef = lsplit(
          singleton(nested(:lparen, ~_)),
          token(:equal),
          ~_
        )

        item.match(match_funcdef) do |defn, body|
          name, lhs, args = extract_funcdef_lhs(defn)
          common_funcdefs = [[lhs, args, body]]

          while sub_items.any?
            next_lhs = nil
            next_body = nil
            next_args = nil
            sub_items.first.match(match_funcdef) do |defn, body|
              _, next_lhs, next_args = extract_funcdef_lhs(defn)
              next_body = body
            end or break

            break unless lhs == next_lhs
            common_funcdefs << [sub_items.first, next_args, next_body]

            sub_items.shift
          end

          elems << parse_funcdefs(name, lhs, common_funcdefs)
        end and next

        elems << parse_line(item)
      end

      AST::Group[elems]
    end

    def extract_funcdef_lhs(elems)
      bang_match = lsplit(
        singleton(~_),
        ~token(:bang),
        starts(~token(:bare), ~_)
      )

      elems.match bang_match do |bang, env, key, args|
        return ["#{env.value}!#{key.value}", Skeleton::Item[[env, bang, key]], args]
      end

      elems.match(starts(~_, ~_)) do |head, rest|
        return [head.value, Skeleton::Item[[head]], rest]
      end

      error!(elems, "invalid funcdef lhs")
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
        return AST::Compensation[parse_command(lhs), parse_command(rhs), item.range, :conditional]
      end
      # Parse double %%!
      item.match(lsplit(~_, token(:d_per_bang), ~_)) do |lhs, rhs|
        return AST::Compensation[parse_command(lhs), parse_command(rhs), item.range, :unconditional]
      end

      # Default
      parse_command(item)
    end

    def parse_vector(vec)
      AST::Vector[parse_terms(vec)]
    end

    def parse_funcdefs(name, lhs, defs)
      range = Lexer::Range.between(defs.first[0], defs.last[0])

      bindings = []
      bodies = []

      defs.each do |(item, args, body)|
        bindings << args
        bodies << [body]
      end

      lam = parse_lambda(name, bindings, bodies, range)
      AST::Assignment[parse_terms(lhs), [lam]]
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

        range = Lexer::Range.between(lhs, rhs)
        lam = parse_lambda(lambda_name, [bindings], [[rhs]], range)
        return AST::Assignment[parse_terms(var), [lam]]
      end

      # Normal assignment
      unless lhs.elems.all? { |elem| elem.token?(:bare) || elem.token?(:var) || elem.token?(:lex_var) || elem.token?(:bang) }
        error!(lhs, "Invalid lhs")
      end

      return AST::Assignment[parse_terms(lhs), parse_terms(rhs)]
    end

    def parse_lambda(name, bindings, bodies, range)
      patterns = parse_bindings(bindings)
      groups = bodies.map { |body| parse_root(Skeleton::Item[body]) }
      return AST::Lambda[name, patterns, groups, range]
    end

    def parse_command(command)
      range = command.range

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
      with(redirects, AST::Command[vec, range])
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

      pattern.match(~token(:var)) do |v|
        return AST::VariablePattern[AST::Variable[v.value]]
      end

      pattern.match(~token(:lex_var)) do |v|
        return AST::VariablePattern[AST::LexVariable[v.value]]
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
      term.match(~token(:intrinsic)) do |intrinsic|
        error!(intrinsic, "use @allow-intrinsics") unless @allow_intrinsics
        return AST::Intrinsic[intrinsic.value]
      end

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
          return parse_lambda("anon@#{term.range.repr}", [before], [[after]], term.range)
        end

        # Anon lambda spanning multiple lines
        item.elems.first.match(lsplit(_, token(:arrow), _)) do
          bindings = []
          bodies = []
          name = "anon@#{term.range.repr}"
          item.elems.each do |elem|
            elem.match(lsplit(~_, token(:arrow), ~_)) do |patterns, body|
              # any further arrow on this line is an empty pattern, asserting
              # that there are no arguments.
              empties = []

              while true
                body.match(rsplit(~_, token(:arrow), ~_)) do |new_body, empty|
                  body = new_body
                  empties << empty
                end or break
              end

              bindings << patterns
              bodies << [body]

              empties.each do |e|
                bindings << Skeleton::Item[[]]
                bodies << [e]
              end

              next
            end or begin
              bodies.last << elem
            end
          end

          return parse_lambda(name, bindings, bodies, term.range)

         # patterns = parse_bindings(bindings)
         # return AST::Lambda[name, patterns, bodies.map { |body| AST::Group[body.map { |line| parse_line(line) }]}]
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
