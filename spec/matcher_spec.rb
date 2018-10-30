describe Magritte::Matcher do
  include Magritte::Matcher::DSL
  let(:input) { "" }
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
end
