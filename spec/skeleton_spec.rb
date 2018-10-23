describe Magritte::Skeleton do
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new(input) }
  let(:tree) { Magritte::Skeleton::Parser.parse(lex) }

  describe "well balanced parenthesis" do
    let(:input) {
      """
      (count-three ?n)
      """
    }

    focus
    it "is accepted by skeleton tree" do
      assert { tree.repr == "(([lparen|.bare/count-three .bind/n|rparen]))"}
    end
  end
end
