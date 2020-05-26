describe Magritte::Env do
  def env(parent, vals={})
    e = Magritte::Env.new(parent)

    vals.each do |key, val|
      e.let(key, val)
    end
    e
  end

  let(:base) { Magritte::Env.empty }

  describe "empty" do
    it "raises missing on get" do
      assert { rescuing(Magritte::Env::MissingVariable) { base.get(:foo) } }
    end
  end

  let(:extended) { env(base, foo: 1) }

  describe "own keys" do
    it "gets" do
      assert { extended.get(:foo) == 1 }
    end

    it "mutates" do
      extended.mut(:foo, 2)
      assert { extended.get(:foo) == 2 }
    end

    it "shadows" do
      extended.let(:foo, 2)
      assert { extended.get(:foo) == 2 }
    end
  end
end
