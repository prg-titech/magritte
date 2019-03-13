module Magritte
  class Runner
    attr_reader :input, :output, :env
    def initialize
      @mutex = Mutex.new
      @output = Channel.new
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

      output_env = Env.empty.extend([@output], [])
      o = Proc.spawn(Code.new { loop { puts @output.read.repr } }, output_env).start
      status = p.wait
      o.join
    rescue CompileError => e
      Status[:fail, reason: Reason::Compile.new(e)]
    rescue ::Interrupt => e
      Status[:fail, reason: Reason::UserInterrupt.new(e)]
    rescue Exception => e
      Status[:fail, reason: Reason::Bug.new(e)]
    else
      status
    ensure
      # p && p.crash!("ended")
      @output.reset!
      @input.reset!
    end
  end
end
