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
      describe "basic" do
        let(:input) {
          """
          (?x => put %x) 1
          """
        }

        it do
          assert { result == "1" }
        end
      end

      describe "assignment" do
        let(:input) {
          """
          x = 2
          put $x
          """
        }

        it do
          assert { result == "2" }
        end
      end

      describe "dynamic assignment" do
        let(:input) {
          """
          x = 2
          $x = -1
          put $x
          """
        }

        it do
          assert { result == "-1" }
        end
      end

      describe "lexical assignment" do
        let(:input) {
          """
          x = 2
          %x = -1
          put $x
          """
        }

        it do
          assert { result == "-1" }
        end
      end

      describe "access assignment" do
        let(:input) {
          """
          e = { v = 2 }
          $e!v = 13
          put $e!v
          """
        }

        it do
          assert { result == "13" }
        end
      end

      describe "mutation" do
        let(:input) {
          """
          x = 1
          (get-x) = put %x
          (set-x ?v) = (%x = $v)
          set-x 10
          get-x
          """
        }

        it do
          assert { result == "10" }
        end
      end

      describe "shadowing" do
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
        put $f
        """
      }

      it do
        assert { results == ["5","<func:f>"] }
      end
    end

    describe "lambda assignment with dynamic var" do
      let(:input) {
        """
        f = 1
        ($f ?x) = put $x
        f 5
        put $f
        """
      }

      it do
        assert { results == ["5","<func:f>"] }
      end
    end

    describe "lambda assignment with lexical var" do
      let(:input) {
        """
        f = 1
        (%f ?x) = put $x
        f 5
        put $f
        """
      }

      it do
        assert { results == ["5","<func:f>"] }
      end
    end

    describe "lambda assignment with access expression" do
      let(:input) {
        """
        e = { f = 5 }
        ($e!f ?x) = (inc %x)
        put ($e!f 3)
        """
      }

      it do
        assert { result == "4" }
      end
    end

    describe "lambda body stretching multiple lines" do
      let(:input) {
        """
        (f ?x) = (
          y = (inc %x)
          z = (inc %y)
          put $z
        )
        put (f 5)
        """
      }

      it do
        assert { result == "7" }
      end
    end

    describe "nested lambda body stretching multiple lines" do
      let(:input) {
        """
        (f ?x ?y) = (
          z = (?a => (
              put (dec $a) 1
          ))
          put (z $x) $y
        )
        put (f 1 2)
        """
      }

      it do
        assert { results == ["0", "1", "2"] }
      end
    end

    describe "lambda body with anon lambda" do
      let(:input) {
        """
        put 1 2 3 | each (?a => put 10; put $a)
        """
      }

      it do
        assert { results == %w(10 1 10 2 10 3) }
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

  describe "environment" do
    describe "creation" do
      let(:input) {
        """
        e = {x = 1; y = 0}
        put %e!x %e!y
        """
      }

      it do
        assert { results = ["1", "0"] }
      end
    end

    describe "complex creation" do
      let(:input) {
        """
        x = 1
        y = 0
        e = {z = $x; k = $y}
        put $e!z $e!k
        """
      }

      it do
        assert { results = ["1", "0"] }
      end
    end

    describe "nesting" do
      let(:input) {
        """
        e = {g = 3}
        e2 = {h = 4}
        e3 = {x = $e; y = $e2}
        put $e3!x!g $e3!y!h
        """
      }

      it do
        assert { results == ["3", "4"] }
      end
    end

    describe "printing" do
      let(:input) {
        """
        e = {g = 3; x = 1}
        put $e
        """
      }

      it do
        assert { result == "{ g = 3; x = 1 }" }
      end
    end

    describe "environment functions" do
      let(:input) {
        """
        e = { x = 2; (f ?y) = (put %x %y) }
        $e!f 1
        """
      }

      it do
        assert { results == ["2", "1"] }
      end
    end
  end

  describe "compensations" do
    describe "unconditional checkpoint" do
      let(:input) {
        """
        exec (=> (put 1 %%! put 2; put 3))
        """
      }

      it do
        assert { results == ["1", "3", "2"] }
      end
    end

    describe "interrupts" do
      let(:input) {
        """
        c = (make-channel)
        exec (=> (
          put 1 %% (put comp > %c)
          put 2 3 4 5 6
        )) | take 2
        get < $c
        """
      }

      it do
        assert { results == ["1", "2", "comp"] }
      end
    end
  end

  describe "conditionals" do
    describe "simple" do
      let(:input) {
        """
        true && put 1
        false || put 2
        true || put 3
        false && put 4
        """
      }

      it do
        assert { results == ["1", "2"] }
      end
    end

    describe "else" do
      let(:input) {
        """
        true && put 1 !! put 2
        false && put 3 !! put 4
        true || put 5 !! put 6
        false || put 7 !! put 8
        """
      }

      it do
        assert { results == ["1", "4", "6", "7"] }
      end
    end

    describe "try" do
      let(:input) {
        """
        try crash && put success !! put crashed
        """
      }

      it do
        assert { result == "crashed" }
      end
    end
  end
end
