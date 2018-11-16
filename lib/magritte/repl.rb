require "readline"
module Magritte
  class REPL
    def initialize(argv)
      @line_num = 0
      @mutex = Mutex.new
      @streamer = Streamer.new do |val|
        @mutex.synchronize { puts val.repr }
      end
      @env = Env.base.extend([], [@streamer])
    end

    def self.run(argv)
      new(argv).run
    end

    def source_name
      "repl~#{@line_num}"
    end

    def evaluate(source)
      ast = Parser.parse(Skeleton.parse(Lexer.new(source_name, source)))
      Proc.spawn(Code.new { Interpret.interpret(ast) }, @env).start
      @streamer.wait_for_close
    rescue ::Interrupt => e
      #pass
    ensure
      @streamer.reopen!
    end

    def process_line
      string = @mutex.synchronize { Readline.readline("; ", true) }
      raise IOError if string.nil?
      evaluate(string)
      return true
    rescue CompileError => e
      @mutex.synchronize { puts "error: #{e.class.name}\n#{e.to_s}" }
      return false
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
