describe Magritte::FreeVars do
  let(:expr) { raise "Abstract" }
  let(:result) { Magritte::FreeVars.scan(expr) }

  def free_vars(node = nil)
    node ||= expr
    result[node]
  end

  # Define helper functions for setting up tests
  # Example: Magritte::AST::Variable["foo"] = _variable("foo")
  Magritte::AST.constants.each do |c|
    c = Magritte::AST.const_get(c)
    define_method("_#{c.short_name}") do |*a|
      c.make(*a)
    end
  end

  describe "a variable" do
    let(:expr) { _variable("foo") }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a lexical variable" do
    let(:expr) { _lex_variable("foo") }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a binder" do
    let(:expr) { _binder("hoge") }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a lambda" do
    let(:expr) { _lambda("x",[_binder("foo")],[_command(_variable("hoge"),[_lex_variable("bar")],[])]) }
    let(:expr2) { _lambda("x",[_binder("foo")],[_command(_variable("hoge"),[_lex_variable("foo")],[])]) }

    it "has a free variables" do
      assert { free_vars == Set.new(["bar"]) }
    end

    it "has no free variables" do
      assert { Magritte::FreeVars.scan(expr2)[expr2].empty? }
    end
  end

  describe "a pipe" do
    let(:expr) { _pipe(_binder("in"),_binder("out")) }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a compensation" do
    let(:expr) { _compensation(_lex_variable("hoge"),_lex_variable("bar"),"boo") }

    it "has a free variable" do
      assert { free_vars == Set.new(["hoge","bar"]) }
    end
  end

  describe "a spawn" do
    let(:expr) { _spawn(_block([_command(_binder("bar"),[_lex_variable("foo")],[])])) }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a command" do
    let(:expr) { _command(_lex_variable("foo"),[_variable("bar")],[]) }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end

  describe "a block" do
    let(:command1) { _command(_binder("foo"),[_lex_variable("hoge")],[]) }
    let(:command2) { _command(_binder("zoo"),[_variable("bar")],[]) }
    let(:expr) { _block([command1,command2]) }

    it "has a free variable" do
      assert { free_vars == Set.new(["hoge"]) }
    end
  end

  describe "a vector" do
    let(:expr) { _vector([_variable("a"),_lex_variable("b")]) }

    it "has a free variable" do
      assert { free_vars == Set.new(["b"]) }
    end
  end
end
