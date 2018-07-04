module Magritte
  module IO
    def put(val)
      # PRINTER.p put: val
      Proc.current.stdout.write(val)
    end

    def get
      out = Proc.current.stdin.read
      # PRINTER.p get: out
      out
    end

    def for_(iterable)
      iterable.each { |val| put(val) }
    end
  end

  class Code
    include Magritte::IO

    def initialize(&block)
      @block = block
    end

    def run(*a)
      instance_exec(*a, &@block)
    end

    def stdin
      Proc.current.stdin
    end

    def stdout
      Proc.current.stdout
    end

    def s(&b)
      Spawn.new(Proc.current.in_ch, Proc.current.out_ch, &b)
    end

    def spawn_collect
      PRINTER.p "main thread"
      c = Collector.new
      Proc.spawn(self, {}, [], [c]).wait
      c.collection
    end

    def pipeline(&b)
    end
  end

  class Spawn
    def self.root(&b)
      new([], [], &b)
    end

    attr_reader :in_ch, :out_ch
    def initialize(in_ch, out_ch, &block)
      @block = block
      @in_ch = in_ch
      @out_ch = out_ch
    end

    def p(i=0, &block)
      c = Channel.new

      # spawn the process, blocking on the output channel
      into(c).spawn.start

      Spawn.new(in_with(c), out_ch, &block)
    end

    def spawn
      # TODO: env
      Proc.spawn(Code.new(&@block), {}, in_ch, out_ch)
    end

    def collect
      collector = Collector.new
      into(collector).spawn.wait
      collector.collection
    end

    def go
      spawn.wait
    end

    def into(*chs)
      Spawn.new(in_ch, out_with(*chs), &@block)
    end

    def from(*chs)
      Spawn.new(in_with(*chs), out_ch, &@block)
    end

    def in_with(*new_ch)
      list_merge(Proc.current.in_ch, new_ch)
    end

    def out_with(*new_ch)
      list_merge(Proc.current.out_ch, new_ch)
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
