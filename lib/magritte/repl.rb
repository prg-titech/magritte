require "readline"
module Magritte
  class REPL
    def initialize(argv)
      @env = Env.base
      @line_num = 0
    end

    def self.run(argv)
      new(argv).run
    end

    def source_name
      "repl~#{@line_num}"
    end

    def evaluate(source)
      ast = Parser.parse(Skeleton.parse(Lexer.new(source_name, source)))
      c = Collector.new
      @env.own_outputs[0] = c
      Proc.spawn(Code.new { Interpret.interpret(ast) }, @env).start
      c.wait_for_close
      c.collection.map(&:repr).join("\n")
    end

    def process_line
      string = Readline.readline("; ", true)
      raise IOError if string.nil?
      output = evaluate(string)
      puts output
      return true
    rescue CompileError => e
      puts "error: #{e.class.name}\n#{e.to_s}"
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
