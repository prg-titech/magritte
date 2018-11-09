module Magritte
  class Code

    module DSL
      include Magritte::Std

      extend self

      def stdin
        Proc.current.stdin
      end

      def stdout
        Proc.current.stdout
      end

      def s(&b)
        s_ { DSL.instance_eval(&b) }
      end

      def s_(&b)
        Spawn.new(Proc.current.env, [], [], &b)
      end
    end

    include DSL

    def initialize(&block)
      @block = block
    end

    def run
      @block.call
    end

    def spawn_collect(env = nil)
      env ||= Env.empty
      c = Collector.new
      Proc.spawn(self, env.extend([], [c])).wait
      c.collection
    end

    def inspect
      "#<Code #{loc}>"
    end

    def loc
      @block.source_location.join(':')
    end
  end

  class PlainCode < Code
    def run(*a)
      @block.call(*a)
    end
  end

  class Spawn
    def self.root(&b)
      new([], [], &b)
    end

    attr_reader :in_ch, :out_ch
    def initialize(env, in_ch, out_ch, &block)
      @env = env
      @in_ch = in_ch
      @out_ch = out_ch
      @block = block
    end

    def p(&block)
      p_ { Code::DSL.instance_eval(&block) }
    end

    def p_(&block)
      # the anonymous pipe channel!
      c = Channel.new

      # spawn the process on the output channel
      into(c).go

      PRINTER.p('spawned in the background')

      Spawn.new(@env, in_with(c), out_ch, &block)
    end

    def as_code
      Code.new(&@block)
    end

    def spawn
      PRINTER.p :spawn => [in_ch, out_ch, as_code]
      # TODO: env
      Proc.spawn(as_code, @env.extend(in_ch, out_ch))
    end

    def collect
      collector = Collector.new
      into(collector).call
      collector.collection
    end

    def go
      spawn.start
    end

    def call
      env = @env.extend(in_ch, out_ch)
      Proc.with_env(env, &@block)
    end

    def into(*chs)
      Spawn.new(@env, in_ch, out_with(*chs), &@block)
    end

    def from(*chs)
      Spawn.new(@env, in_with(*chs), out_ch, &@block)
    end

    def in_with(*new_ch)
      list_merge(in_ch, new_ch)
    end

    def out_with(*new_ch)
      list_merge(out_ch, new_ch)
    end

  private
    def list_merge(orig, new)
      orig = orig.dup

      new.each_with_index do |e, i|
        orig[i] = e
      end

      orig
    end
  end
end
