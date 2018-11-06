require "readline"
module Magritte
  module REPL
    def self.evaluate(source_name, source, env)
      ast = Parser.parse(Skeleton.parse(Lexer.new(source_name, source)))
      Code.new do
        Interpret.interpret(ast)
      end.spawn_collect(env).map(&:repr).join("\n")
    end

    def self.process_line(line_number, env)
      string = Readline.readline("; ", true)
      raise IOError if string.nil?
      output = evaluate("repl~#{line_number}", string, env)
      puts output
      return true
    rescue CompileError => e
      puts "error: #{e.class.name}\n#{e.to_s}"
      return false
    end

    def self.run(argv)
      line_number = 0
      env = Env.empty
      Builtins.load(env)
      loop do
        line_number += 1 if process_line(line_number, env)
      end
    rescue IOError
      # Pass
      puts
    end
  end
end
