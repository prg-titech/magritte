module Magritte
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def compile_files
      load "#{LIB_DIR}/magritte/compiler.rb"

      # TODO
      file = @files[0]
      ast = Parser.parse(Skeleton.parse(Lexer.new(file, File.read(file))))

      Magritte::Compiler.new(ast).compile.render($stdout)
    end

    def run
      parse_args

      return compile_files if @mode == :compile

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
      @mode = :interpret

      while (head = @argv.shift)
        case head
        when '-r' then @libs << @argv.shift
        when '-c' then @mode = :compile
        else @files << head
        end
      end
    end
  end
end
