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
      Proc.spawn(Code.new { Interpret.interpret(ast) }, @env).start
      @streamer.wait_for_close
    rescue ::Interrupt => e
      #pass
      false
    rescue CompileError => e
      @mutex.synchronize { puts "error: #{e.class.name}\n#{e.to_s}" }
      false
    else
      @streamer.reset!
      @input.reset!
      true
    end

    def process_line
      string = @mutex.synchronize { Readline.readline("; ", true) }
      raise IOError if string.nil?
      return false if string =~ /\A\s*\z/m
      evaluate(string)
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
