describe Magritte::Lexer do
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new(input) }
  let(:tokens) { lex.to_a }

  # Define helper functions for setting up tests
  # Example: Magritte::AST::Variable["foo"] = _variable("foo")
  define_method("_token") do |type, value = nil, range = nil|
    Magritte::Lexer::Token.new(type, value, range)
  end

  describe "some delimiters" do
    let(:input) {
      """
      (       [ $hoge
      """
    }

    it "parses basic delimiters" do
      assert { tokens == [_token(:lparen), _token(:lbrack), _token(:var,"hoge"), _token(:nl), _token(:eof)] }
    end
  end

  describe "some basic keywords" do
    let(:input) {
      """
      [({} )   ]    = %a
      """
    }

    it "parses basic keywords" do
      assert { tokens == [_token(:lbrack), _token(:lparen), _token(:lbrace), _token(:rbrace), _token(:rparen), _token(:rbrack), _token(:equal), _token(:lex_var, "a"), _token(:nl), _token(:eof)] }
    end
  end

  describe "function header" do
    let(:input) {
      """
      (func ?n)
      """
    }

    it "parses basic function header" do
      assert { tokens == [_token(:lparen), _token(:bare, "func"), _token(:bind, "n"), _token(:rparen), _token(:nl), _token(:eof)] }
    end
  end

  describe "error recovery tokens" do
    let(:input) {
      """
      ||    &&  !! %%%%!&&
      """
    }

    it "parses tokens correctly" do
      assert { tokens == [_token(:bar_bar), _token(:amp_amp), _token(:excl_excl), _token(:per_per), _token(:per_per_excl), _token(:amp_amp), _token(:nl), _token(:eof)] }
    end
  end

  describe "oprators" do
    let(:input) {
      """
      |     &  ==   =>    
      """
    }

    it "parses operators" do
      assert { tokens == [_token(:bar), _token(:amp), _token(:equal), _token(:equal), _token(:arrow), _token(:nl), _token(:eof)] }
    end
  end

  describe "numbers" do
    let(:input) {
      """
      2     6.28    0.00001   1.   -5.4
      """
    }

    it "parses numbers correctly" do
      assert { tokens == [_token(:num, "2"), _token(:num, "6.28"), _token(:num, "0.00001"), _token(:num, "1."), _token(:num,"-5.4"), _token(:nl), _token(:eof)] }
    end
  end

  describe "strings" do
    let(:input) {
      """
      \"asksnz-zwjdfqw345 r8 ewn    ih2wu\\\" wihf002+4-r9+***.m.-< \\\"\"
      """
    }

    it "parses strings correctly" do
      assert { tokens == [_token(:bareword, "asksnz-zwjdfqw345 r8 ewn    ih2wu\\\" wihf002+4-r9+***.m.-< \\\""), _token(:nl), _token(:eof)] }
    end
  end

  describe "channel semantics" do
    let(:input) {
      """
      channel = (make-channel)
      reader < $channel
      writer > $channel
      """
    }

    it "parses channel semantics" do
      assert { tokens == [_token(:bare, "channel"), _token(:equal), _token(:lparen), _token(:bare, "make-channel"), _token(:rparen), _token(:nl), _token(:bare, "reader"), _token(:read_from), _token(:var, "channel"), _token(:nl), _token(:bare, "writer"), _token(:write_to), _token(:var, "channel"), _token(:nl), _token(:eof)] }
    end
  end
end
