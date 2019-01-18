require "readline"
module Magritte
  class REPL
    def initialize(argv)
      @line_num = 0
      @input_num = 0
      @mutex = Mutex.new
      @streamer = Streamer.new do |val|
        @mutex.synchronize { puts val.repr }
      end

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

      @env = Env.base.extend([@input], [@streamer])
      @env.let('LOG', Value::Channel.new(@streamer))
    end

    def self.run(argv)
      new(argv).run
    end

    def source_name
      "repl~#{@line_num}"
    end

    def input_name
      "#{source_name}<#{@input_num-1}"
    end

    def evaluate(source)
      ast = Parser.parse(Skeleton.parse(Lexer.new(source_name, source)))
      p = Proc.spawn(Code.new { Interpret.interpret(ast) }, @env)
      status = p.wait
      @streamer.wait_for_close
    rescue CompileError => e
      Status[:fail, reason: Reason::Compile.new(e)]
    else
      status
    ensure
      p && p.crash!("ended")
    end

    def process_line
      string = @mutex.synchronize { Readline.readline("; ", true) }
      raise IOError if string.nil?
      return false if string =~ /\A\s*\z/m
      status = evaluate(string)
      @mutex.synchronize { puts "% #{status.repr}" }
      !status.fail?
    rescue ::Interrupt => e
      puts "^C"
      false
    ensure
      @streamer.reset!
      @input.reset!
    end

    def run
      loop do
        @line_num += 1 if process_line
      end
    rescue IOError
      # Pass
      puts
    end
  end
end
