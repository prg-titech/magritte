describe Magritte::FreeVars do
  let(:expr) { raise "Abstract" }
  let(:result) { Magritte::FreeVars.scan(expr) }

  def free_vars(node = nil)
    node ||= expr
    result[node]
  end

  describe "a variable" do
    let(:expr) { Magritte::AST::Variable["foo"] }

    it "has no free variables" do
      assert { free_vars.empty? }
    end
  end

  describe "a lexical variable" do
    let(:expr) {Magritte::AST::LexVariable["foo"] }

    it "has a free variable" do
      assert { free_vars == Set.new(["foo"]) }
    end
  end
end
