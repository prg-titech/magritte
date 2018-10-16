describe Magritte::AST do
  let(:var) { Magritte::AST::Variable["foo"] }
  let(:spawn) { Magritte::AST::Spawn[var] }
  let(:command) { Magritte::AST::Command[var,["arg1","arg2","arg3"]] }
  let(:block) { Magritte::AST::Block[[command,command]] }

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

    it "equals itself" do
      assert { var == var }
    end

    it "equals object with same state" do
      assert { var == Magritte::AST::Variable["foo"] }
    end

    it "does not equal objects with different state" do
      assert { var != Magritte::AST::Variable["foob"] }
    end

    it "does not equal different objects" do
      assert { var != spawn }
    end

    it "hashes correctly" do
      hash = {}
      hash[var] = 1
      assert { hash[Magritte::AST::Variable["foo"]] == 1 }
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

    it "equals itself" do
      assert { spawn == spawn }
    end

    it "equals object with same state" do
      assert { spawn == Magritte::AST::Spawn[var] }
    end

    it "does not equal objects with different state" do
      assert { spawn != Magritte::AST::Spawn[Magritte::AST::Variable["foob"]] }
    end

    it "does not equal different objects" do
      assert { spawn != var }
    end
  end

  describe "list recursive nodes" do
    it "has lines" do
      assert { block.lines == [command,command] }
    end

    describe "maps" do
      let(:mapped) { block.map { |val| val.head.name }}

      it "maps" do
        assert { mapped.is_a? Magritte::AST::Block }
        assert { mapped.lines.map { |elem| elem.is_a? String }.all? }
        assert { mapped.lines.map { |elem| elem == "foo" }.all? }
      end
    end

    it "equals itself" do
      assert { block == block }
    end

    it "equals object with same state" do
      assert { block == Magritte::AST::Block[[command,command]] }
    end

    it "does not equal objects with different state" do
      assert { block != Magritte::AST::Block[[]] }
    end

    it "does not equal different objects" do
      assert { block != spawn }
    end
  end
end
