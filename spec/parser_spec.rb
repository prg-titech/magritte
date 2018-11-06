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
      assert { ast.elems.first.elems[0].is_a?(Magritte::AST::String) }
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

  describe "variables" do
    let(:input) {
      """
      [$a %n ?e]
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.elems[0].is_a?(Magritte::AST::Variable) }
      assert { ast.elems.first.elems[1].is_a?(Magritte::AST::LexVariable) }
      assert { ast.elems.first.elems[2].is_a?(Magritte::AST::Binder) }
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

  describe "lambda" do
    let(:input) {
      """
      (?x ?y => add x y)
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Lambda) }
      assert { ast.elems.first.name == "anon@test@1:7~1:25" }
      assert { ast.elems.first.patterns.size == 2 }
      assert { ast.elems.first.patterns[0].is_a?(Magritte::AST::Binder) }
      assert { ast.elems.first.patterns[0].name == "x" }
      assert { ast.elems.first.bodies.size == 1 }
      assert { ast.elems.first.bodies[0].is_a?(Magritte::AST::Command) }
    end
  end

  describe "pipe" do
    let(:input) {
      """
      f $a | put
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Pipe) }
      assert { ast.elems.first.input.is_a?(Magritte::AST::Command) }
      assert { ast.elems.first.output.is_a?(Magritte::AST::String) }
    end
  end

  describe "spawn" do
    let(:input) {
      """
      & command arg1
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Spawn) }
      assert { ast.elems.first.expr.is_a?(Magritte::AST::Command) }
    end
  end
end
