describe Magritte::Lexer do
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new(input) }
  let(:tokens) { lex.to_a }

  describe "some delimiters" do
    let(:input) {
      """
      (       [ $hoge
      """
    }

    it "parses basic delimiters" do
      binding.pry
      assert { tokens == nil }
    end
  end
end
