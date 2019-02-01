module Magritte
  class Runner
    attr_reader :input, :output
    def initialize
      @mutex = Mutex.new
      @output = Streamer.new do |val|
        @mutex.synchronize { puts val.repr }
      end
      @input_num = 1

      @input = InputStreamer.new do
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

      @env = Env.base.extend([@input], [@output])
      @env.let('LOG', Value::Channel.new(@output))
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
      @output.wait_for_close
    rescue CompileError => e
      Status[:fail, reason: Reason::Compile.new(e)]
    else
      status
    ensure
      # p && p.crash!("ended")
      @output.reset!
      @input.reset!
    end
  end
end
