require "readline"
module Magritte
  class REPL
    def initialize
      @line_num = 0
      @input_num = 0
      @runner = Runner.new
    end

    def self.run(*a)
      new(*a).run
    end

    def source_name
      "repl~#{@line_num}"
    end

    def input_name
      "#{source_name}<#{@input_num-1}"
    end

    def process_line
      string = @runner.synchronize { Readline.readline("; ", true) }
      raise IOError if string.nil?
      (Readline::HISTORY.pop; return false) if string =~ /\A\s*\z/m
      status = @runner.evaluate(source_name, string)
      @runner.synchronize { puts "% #{status.repr}" }
      !status.fail?
    rescue ::Interrupt => e
      puts "^C"
      false
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
