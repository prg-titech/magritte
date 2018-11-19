describe Magritte::Matcher do
  include Magritte::Matcher::DSL
  abstract(:input)
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:tree) { Magritte::Skeleton::Parser.parse(lex).elems.first }
  let(:matcher) { raise "Abstract" }
  let(:match_vars) { matcher.match_vars(tree) }

  describe "a single token" do
    let(:input) {
      """
      $x
      """
    }

    describe "underscore" do
      let(:matcher) { singleton(~_) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == ".var/x" }
      end
    end

    describe "token matcher" do
      let(:matcher) { singleton(~token(:var)) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == ".var/x" }
      end
    end

    describe "failed token matcher" do
      let(:matcher) { singleton(~token(:pipe)) }

      it "fails" do
        assert { match_vars.nil? }
      end
    end
  end

  describe "nesting" do
    let(:input) {
      """
      (func)
      """
    }

    describe "underscore" do
      let(:matcher) { singleton(~_) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == "[lparen|.bare/func|rparen]" }
      end
    end

    describe "nested" do
      let(:matcher) { singleton(~nested(:lparen,_)) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == "[lparen|.bare/func|rparen]" }
      end
    end

    describe "specific nested" do
      let(:matcher) { singleton(~nested(:lparen,singleton(token(:bare)))) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == "[lparen|.bare/func|rparen]" }
      end
    end
  end

  describe "start/end" do
    let(:input) {
      """
      g %a
      """
    }

    describe "test start" do
      let(:matcher) { ~starts(token(:bare),~singleton(token(:lex_var))) }

      it "works" do
        assert { match_vars.size == 2 }
        assert { match_vars[0].repr == "(.lex_var/a)" }
        assert { match_vars[1].repr == "(.bare/g .lex_var/a)" } # Is this the order we want for the captures?
      end
    end

    describe "test end" do
      let(:matcher) { ~ends(token(:lex_var),singleton(token(:bare))) }

      it "works" do
        assert { match_vars.size == 1 }
        assert { match_vars.first.repr == "(.bare/g .lex_var/a)" }
      end
    end
  end

  describe "splits" do
    let(:input) {
      """
      p1 | p2 | p3
      """
    }

    describe "test lsplit" do
      let(:matcher) { lsplit(~singleton(token(:bare)),token(:pipe),~_) }

      it "works" do
        assert { match_vars.size == 2 }
        assert { match_vars[0].repr == "(.bare/p1)" }
        assert { match_vars[1].repr == "(.bare/p2 .pipe .bare/p3)" }
      end
   end

    describe "test rsplit" do
      let(:matcher) { rsplit(~_,token(:pipe),~_) }

      it "works" do
        assert { match_vars.size == 2 }
        assert { match_vars[0].repr == "(.bare/p1 .pipe .bare/p2)" }
        assert { match_vars[1].repr == "(.bare/p3)" }
      end
    end
  end

  describe "lambda" do
    let(:input) {
      """
      (f ?x) = add $x 1
      """
    }

    describe "test lsplit" do
      let(:matcher) { lsplit(~_, token(:equal), ~_) }

      it "works" do
        assert { match_vars.size == 2 }
        assert { match_vars[0].repr == "([lparen|.bare/f .bind/x|rparen])" }
        assert { match_vars[1].repr == "(.bare/add .var/x .num/1)" }
      end
    end
  end
end
