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
      runner = Runner.new
      @files.each do |f|
        status = runner.evaluate(f, File.read(f))
        runner.synchronize { puts "% #{status.repr}" } if status.fail?
      end
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
