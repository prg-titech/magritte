describe Magritte::Parser do
  abstract(:input)

  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse_root(skel) }

  describe "a vector" do
    let(:input) {
      """
      put [a b c]
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.is_a?(Magritte::AST::Command) }
      assert { ast.elems.first.vec.size == 2 }
      assert { ast.elems.first.vec.inspect == "[#<Magritte::AST::String[\"put\"]>, #<Magritte::AST::Vector[**[#<Magritte::AST::String[\"a\"]>, #<Magritte::AST::String[\"b\"]>, #<Magritte::AST::String[\"c\"]>]]>]" }
    end
  end

  describe "access" do
    let(:input) {
      """
      put $foo!bar
      """
    }

    it "parses correctly" do
      assert { ast.elems.size == 1 }
      assert { ast.elems.first.vec[1].is_a?(Magritte::AST::Access) }
    end
  end

  describe "variables" do
    let(:input) {
      """
      $x = 1
      %n = 2
      """
    }

    #it "parses correctly" do
    #  assert { ast.elems.size == 2 }
    #  assert { ast.elems.all?(Magritte::AST::Assignment) }
    #  #assert { ast.elems[0].lhs.inspect == "#<Magritte::AST::Variable[\"x\"]>" }
    #  assert { ast.elems[0].rhs.inspect == "#<Magritte::AST::Number[\"1\"]>" }
    #  assert { ast.elems[1].lhs.inspect == "#<Magritte::AST::LexVariable[\"n\"]>" }
    #  assert { ast.elems[1].rhs.inspect == "#<Magritte::AST::Number[\"2\"]>" }
    #end
  end

  describe "command" do
    let(:input) {
      """
      multi-arg-command arg1 arg2 >$out <$in
      """
    }

    #it "parses correctly" do
    #  assert { ast.elems.size == 1 }
    #  assert { ast.elems.first.is_a?(Magritte::AST::Command) }
    #  assert { ast.elems.first.vec.inspect == "[#<Magritte::AST::String[\"multi-arg-command\"]>, #<Magritte::AST::String[\"arg1\"]>, #<Magritte::AST::String[\"arg2\"]>]" }
    #  assert { ast.elems.first.redirects.inspect == "[#<Magritte::AST::Redirect[:<, *#<Magritte::AST::Variable[\"in\"]>]>, #<Magritte::AST::Redirect[:>, *#<Magritte::AST::Variable[\"out\"]>]>]" }
    #end
  end

  describe "lambda" do
    let(:input) {
      """
      f = (?x ?y => add x y)
      """
    }

    #it "parses correctly" do
    #  assert { ast.elems.size == 1 }
    #  assert { ast.elems[0].is_a?(Magritte::AST::Assignment) }
    #  #assert { ast.elems[0].lhs.inspect == "#<Magritte::AST::String[\"f\"]>" }
    #  assert { ast.elems[0].rhs.is_a?(Magritte::AST::Lambda) }
    #  assert { ast.elems[0].rhs.name == "anon@test@1:11~1:29" }
    #  assert { ast.elems[0].rhs.patterns.inspect == "[#<Magritte::AST::Binder[\"x\"]>, #<Magritte::AST::Binder[\"y\"]>]" }
    #  assert { ast.elems[0].rhs.bodies.inspect == "[#<Magritte::AST::Command[**[#<Magritte::AST::String[\"add\"]>, #<Magritte::AST::String[\"x\"]>, #<Magritte::AST::String[\"y\"]>], **[]]>]" }
    #end
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
      assert { ast.elems.first.producer.is_a?(Magritte::AST::Command) }
      assert { ast.elems.first.consumer.is_a?(Magritte::AST::Command) }
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
