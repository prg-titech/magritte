module Magritte
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      parse_args

      if @files.any?
        run_files
      else
        run_repl
      end
    end

    def run_repl
      REPL.run
    end

    def run_files
      @files.each do |f|
        runner = Runner.new
        status = runner.evaluate(f, File.read(f))

        if runner.env.key?('__main__')
          runner.evaluate(f, '__main__')
        end

        runner.synchronize { puts "% #{status.repr}" } if status.fail?
      end

      # XXX hack in case some threads don't exit
      # will investigate this more when we have a
      # proper vm
      PRINTER.p(alive: (Thread.list - [Thread.current]))
      exit! 0
    end

    def parse_args
      @libs = []
      @files = []

      while (head = @argv.shift)
        case head
        when '-r' then @libs << @argv.shift
        else @files << head
        end
      end
    end
  end
end
