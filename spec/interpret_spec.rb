describe Magritte::Interpret do
  let(:input) { "" }
  let(:lex) { Magritte::Lexer.new("test",input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse_root(skel) }
  let(:env) { Magritte::Builtins.load(Magritte::Env.empty) }
  let(:results) { ast;
    Magritte::Spawn.s_ env do
      Magritte::Interpret.interpret(ast)
    end.collect.map(&:repr)
  }
  let(:result) { results.join("\n") }

  describe "simple input" do
    describe "a vector" do
      let(:input) {
        """
        put [a b c]
        """
      }

      it "is interpreted correctly" do
        assert { result == '[a b c]' }
      end
    end

    describe "single string" do
      let(:input) {
        """
        put hello
        """
      }

      it "is interpreted correctly" do
        assert { result == "hello" }
      end
    end

    describe "nested expression" do
      let(:input) {
        """
        put (put 1)
        """
      }

      it "is interpreted correctly" do
        assert { result == "1" }
      end
    end

    describe "early exit for collectors" do
      let(:input) {
        """
        put 1 2 3 4 5 6 7 8 9 10 | (& drain; & drain)
        # sleep 1 # todo: uhhhh we get recursive locking if we remove this
        """
      }

      it "is interpreted correctly" do
        assert { results.size == 10 }
      end
    end

    describe "early exit for vectors" do
      let(:input) {
        """
        for [0 (put 1 2 3 4 5 6 7 8 9 10 | (& drain; & drain))]
        # sleep 1 # todo: uhhhh we get recursive locking if we remove this
        """
      }

      it "is interpreted correctly" do
        assert { results.size == 11 }
      end
    end

    describe "slide example" do
      let(:input) {
        """
        count-forever | (& drain; & drain; & drain) | take 30
        """
      }

      it do
        assert { results.size == 30 }
      end
    end
  end
end
