describe Magritte::AST do
  let(:var) { Magritte::AST::Variable["foo"] }
  let(:spawn) { Magritte::AST::Spawn[var] }

  describe "data nodes" do

    it "has a name" do
      assert { var.name == "foo" }
    end

    describe "maps" do
      let(:mapped) { var.map { never_called } }

      it "maps" do
        assert { mapped.is_a? Magritte::AST::Variable }
        assert { mapped.name == "foo" }
      end
    end
  end

  describe "recursive nodes" do
    it "has an expr" do
      assert { spawn.expr == var }
    end

    describe "maps" do
      let(:mapped) { spawn.map { Magritte::AST::Variable["bar"]}}

      it "maps" do
        assert { mapped.is_a? Magritte::AST::Spawn }
        assert { mapped.expr.is_a? Magritte::AST::Variable }
        assert { mapped.expr.name == "bar"}
      end
    end
  end
end

