describe Magritte::Skeleton do
  abstract(:input)
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:tree) { Magritte::Skeleton::Parser.parse(lex) }

  describe "well balanced parenthesis" do
    let(:input) {
      """
      (a ?n)
      """
    }

    it "is accepted by skeleton tree" do
      assert { tree.repr == "(([lparen|.bare/a .bind/n|rparen]))"}
    end
  end

  describe "expression with nested scope" do
    let(:input) {
      """
      (a ?x) = (a (b c d) e)
      """
    }

    it "is parsed correctly" do
      assert { tree.repr == "(([lparen|.bare/a .bind/x|rparen] .equal [lparen|.bare/a [lparen|.bare/b .bare/c .bare/d|rparen] .bare/e|rparen]))" }
    end
  end

  describe "multi-line program" do
    let(:input) {
      """
      x = 5
      a = add $x 2
      """
    }

    it "is parsed as two items" do
      assert { tree.repr == "((.bare/x .equal .num/5) (.bare/a .equal .bare/add .var/x .num/2))" }
    end
  end

  describe "nested scope startin and ending on different lines" do
    let(:input) {
      """
      x = {
         a =     \"book\"
           b = (f 5 %s $d)
         y = {    
         }
      }
      """
    }

    it "is parsed correctly" do
      assert { tree.repr == "((.bare/x .equal [lbrace|(.bare/a .equal .string/book) (.bare/b .equal [lparen|.bare/f .num/5 .lex_var/s .var/d|rparen]) (.bare/y .equal [lbrace||rbrace])|rbrace]))" }
    end
  end

  describe "scope using square brackets" do
    let(:input) {
      """
      s [
            (=> c > %ch)
        (=> d < %ch)
          ]
      """
    }

    it "parses correctly" do
      assert { tree.repr == "((.bare/s [lbrack|[lparen|.arrow .bare/c .gt .lex_var/ch|rparen] [lparen|.arrow .bare/d .lt .lex_var/ch|rparen]|rbrack]))" }
    end
  end

  describe "more tests" do
    let(:input) {
      """
      $foo!bar
      """
    }

    it "parses correctly" do
      assert { tree.repr == "((.var/foo .bang .bare/bar))" }
    end
  end

  describe "nesting error" do
    let(:input) {
      """
      [b
      """
    }

    it "throws an error" do
      err = assert_raises { tree }
      assert { err.message == "Unmatched nesting at test@1:7~2:1" }
    end
  end
end
