module Magritte
  class Frame
    attr_reader :env, :lex_env
    attr_reader :compensations
    def initialize(p, env, lex_env = nil)
      @env = env
      #@lex_env = lex_env || p.lex_env
      @proc = p
      @compensations = []
      @tail = false
      @elim = false
    end

    def tail!; @tail = true end
    def tail?; @tail end

    def elim!; @compensations = []; @elim = true end
    def elim?; @elim end

    def compensate(status)
      @tail = false
      while c = @compensations.shift
        c.run
      end

      unregister_channels
    end

    def checkpoint
      @tail = false
      while c = @compensations.shift
        c.run_checkpoint
      end

      unregister_channels
    end

    def add_compensation(comp)
      @compensations << comp
    end

    def repr
      "f:[>#{@env.stdout} <#{@env.stdin}]"
    end

    def to_s
      repr
    end

    def inspect
      "#<Frame #{repr} [#{@compensations.map(&:repr).join(' ')}]>"
    end

    def thread
      @proc.thread
    end

    def open_channels
      @env.each_input { |c| c.add_reader(self) }
      @env.each_output { |c| c.add_writer(self) }
    end

    def unregister_channels
      PRINTER.p unregister_channels: [@env.stdin.to_s, @env.stdout.to_s]
      @env.each_input { |c| c.remove_reader(self) }
      @env.each_output { |c| c.remove_writer(self) }
    end
  end
end
