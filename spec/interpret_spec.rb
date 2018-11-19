describe Magritte::Interpret do
  abstract(:input)

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

    describe "single word" do
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

    describe "lambdas" do
      let(:input) {
        """
        (?x => put $x) 1
        """
      }

      it do
        assert { result == "1" }
      end
    end

    describe "lexical vars" do
      let(:input) {
        """
        (?x => put %x) 1
        """
      }

      it do
        assert { result == "1" }
      end
    end

    describe "closures" do
      let(:input) {
        """
        x = 100
        f = (?y => add %x %y)
        x = 0
        f 3
        """
      }

      it do
        assert { result == "103" }
      end
    end

    describe "root-level blocks" do
      let(:input) {
        """
        (put 1)
        """
      }

      it do
        assert { result == "1" }
      end
    end
  end

  describe "special syntax" do
    describe "lambda assignment" do
      let(:input) {
        """
        (f ?x) = put $x
        f 5
        """
      }

      it do
        assert { result == "5" }
      end
    end
  end

  describe "standard library" do
    describe "range" do
      let(:input) {
        """
        range 5
        """
      }

      it do
        assert { results == ["0", "1", "2", "3", "4"] }
      end
    end

    describe "repeat" do
      let(:input) {
        """
        repeat 3 7
        """
      }

      it do
        assert { results == ["7", "7", "7"] }
      end
    end

    describe "inc" do
      let(:input) {
        """
        inc 1
        inc 5
        """
      }

      it do
        assert { results == ["2","6"] }
      end
    end

    describe "dec" do
      let(:input) {
        """
        dec 1
        dec 5
        """
      }

      it do
        assert { results == ["0","4"] }
      end
    end
  end
end
