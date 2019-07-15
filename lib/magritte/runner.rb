module Magritte
  class Runner
    attr_reader :input, :output, :env
    def initialize
      @mutex = Mutex.new
      @input_num = 1

      @env = Env.empty
      setup_channels
      Builtins.load(@env)
    end

    def reset_channels
      @env.stdin.reset!
      @env.stdout.reset!
    end

    def setup_channels
      input = InputStreamer.new do
        begin
          source = @mutex.synchronize {
            @input_num += 1
            Readline.readline('<= ', false)
          }

          (puts; next) if source.nil?

          source = "for [#{source}]"

          ast = Parser.parse(Skeleton.parse(Lexer.new(input_name, source)))

          Spawn.s_ { Interpret.interpret(ast) }.collect
        rescue CompileError
          []
        end
      end

      output = Streamer.new do |val|
        @mutex.synchronize { puts val }
      end

      @env.set_output(0, output)
      @env.set_input(0, input)
    end

    def input_name
      "#{@source_name}<#{@input_num-1}"
    end

    def synchronize(&b)
      @mutex.synchronize(&b)
    end

    def evaluate(source_name, source)
      # TODO: code smell ><
      @source_name = source_name

      ast = Parser.parse(Skeleton.parse(Lexer.new(source_name, source)))
      p = Proc.spawn(Code.new { Interpret.interpret(ast) }, @env)

      status = p.wait
    rescue CompileError => e
      Status[:fail, reason: Reason::Compile.new(e)]
    rescue ::Interrupt => e
      Status[:fail, reason: Reason::UserInterrupt.new(e)]
    rescue Exception => e
      Status[:fail, reason: Reason::Bug.new(e)]
    else
      status
    ensure
      reset_channels
    end
  end
end
