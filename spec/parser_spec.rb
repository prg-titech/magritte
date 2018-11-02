describe Magritte::Parser do
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse_root(skel) }

  describe "a vector" do
    let(:input) {
      """
      [a b c]
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Vector) }
      assert { ast.elems.first.elems.size == 3 }
    end
  end

  describe "access" do
    let(:input) {
      """
      $foo!bar
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Access) }
    end
  end

  describe "variable" do
    let(:input) {
      """
      $a
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Variable) }
    end
  end

  describe "lex variable" do
    let(:input) {
      """
      %n
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::LexVariable) }
    end
  end

  describe "binder" do
    let(:input) {
      """
      ?n
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Binder) }
    end
  end

  describe "command" do
    let(:input) {
      """
      multi-arg-command arg1 arg2 >$out <$in
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Command) }
      assert { ast.elems.first.head.is_a?(Magritte::AST::String) }
      assert { ast.elems.first.args.all?(Magritte::AST::String) }
      assert { ast.elems.first.redirects.size == 2 }
    end
  end
end
