f.describe Magritte::Runtime do
  abstract(:input)

  let(:lex) { Magritte::Lexer.new(input_name, input) }
  let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
  let(:ast) { Magritte::Parser.parse(skel) }
  # let(:artifact) { Magritte::VM::Compiler.compile(ast) }

  let(:scheduler) { Magritte::Runtime::Scheduler.new(logger: $stdout) }

  let(:output) { scheduler.spawn_root(ast, Magritte::Env.base) }

  let(:result) { output; scheduler.run; output.output }

  let(:res) { result.map(&:repr) }

  let(:input_name) { "testy" }

  describe 'basic code' do
    let(:input) do
      """
      put 1
      put 2
      put 3 4
      """
    end

    it 'does a thing' do
      assert { res == %w(1 2 3 4) }
    end
  end

  describe 'collectors' do
    let(:input) do
      """
      for [(put 1) (put (put 2))]
      """
    end

    it 'does a thing' do
      assert { res == %w(1 2) }
    end
  end

  describe 'functions' do
    let(:input) do
      """
      (f ?x) = add 1 %x

      f 2
      """
    end

    it 'does a thing' do
      assert { res == %w(3) }
    end
  end

  describe 'pipes' do
    let(:input) do
      """
      put 1 2 | (get; get)
      """
    end

    it 'does a thing' do
      assert { res == %w(1 2) }
    end
  end
end
