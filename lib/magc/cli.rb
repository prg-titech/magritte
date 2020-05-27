module Magritte
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def compile_files(files)
      files.each do |file|
        ast = Parser.parse(Skeleton.parse(Lexer.new(file, File.read(file))))

        compiler = Magritte::Compiler.new(ast)
        compiler.compile
        compiler.render_decomp(File.open("#{file}x", 'w'))
        compiler.render(File.open("#{file}c", 'w'))
      end
    end

    def run
      compile_files(@argv)
    end
  end
end
