describe Magritte::FreeVars do
  abstract(:input)
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse_root(skel) }
  let(:result) { Magritte::FreeVars.scan(ast) }

  def free_vars(node = nil)
    node ||= ast
    result[node]
  end

  describe "a variable" do
    let(:input) {
      """
      $foo
      """
    }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a lexical variable" do
    let(:input) {
      """
      %foo
      """
    }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a binder" do
    let(:input) {
      """
      ?x
      """
    }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a lambda" do
    describe "has a free variable" do
      let(:input) {
        """
        (x ?foo) = $hoge %bar
        """
      }

      it "has a free variables" do
        assert { free_vars == Set.new(["bar"]) }
      end
    end

    describe "has no free variable" do
      let(:input) {
        """
        (x ?foo) = $hoge %foo
        """
      }

      it "has no free variables" do
        assert { free_vars.empty? }
      end
    end
  end

  describe "a pipe" do
    let(:input) {
      """
      ?in | ?out
      """
    }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  #describe "a compensation" do
  #  let(:input) {
  #    """
  #    %command %% %reset
  #    """
  #  }

  #  it "has a free variable" do
  #    assert { free_vars == Set.new(["hoge","bar"]) }
  #  end
  #end

  describe "a spawn" do
    let(:input) {
      """
      & $x %foo
      """
    }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a command" do
    let(:input) {
      """
      %foo $bar
      """
    }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a block" do
    let(:input) {
      """
      (foo %hoge)
      (zoo $bar)
      """
    }

    it "has a free variable" do
      assert { free_vars == Set.new(["hoge"]) }
    end
  end

  describe "a vector" do
    let(:input) {
      """
      [$a %b]
      """
    }

    it "has a free variable" do
      assert { free_vars == Set.new(["b"]) }
    end
  end
end
