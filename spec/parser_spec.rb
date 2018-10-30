describe Magritte::Parser do
  include Magritte::Matcher::DSL
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse_root(skel) }

  describe "a vector" do
    let(:input) {
      """
      [a b c &&]
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Vector) }
      assert {ast.elems.first.elems.size == 3 }
    end
  end
end
