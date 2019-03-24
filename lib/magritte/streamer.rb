module Magritte

  class Streamer < Channel
    def initialize(&b)
      setup_id
      @output = b
      @writers = Set.new
      @close_waiters = []
      @open = true
    end

    def to_s
      "streamer##{@id}:#{@output.source_location.join(':')}"
    end

    def add_reader(*); end
    def remove_reader(*); end

    def remove_writer(p)
      action = @mutex.synchronize do
        next :nop unless @open
        @writers.delete(p)

        next :nop unless @writers.empty?

        @open = false
        @close_waiters.each { |t| t.run } # if action == :close
        @close_waiters.clear
      end
    end

    def read
      raise 'not readable'
    end

    def write(val)
      @output.call(val)
    end

    require 'pry'
    def wait_for_close
      PRINTER.p("waiting for close #{self} #{@writers}")

      @mutex.synchronize do
        next unless @open
        @close_waiters << Thread.current
        @mutex.sleep
      end

      Proc.current? && Proc.check_interrupt!
    end

    def reset!
      @mutex.synchronize do
        @mutex.log 'reset'
        @close_waiters.each { |t| t.run } # if action == :close
        @close_waiters.clear

        @open = true
        @writers.clear
      end
    end

    def inspect_crit
      "#<#{self.class.name}>"
    end
  end

  class InputStreamer < Channel
    def initialize(&b)
      setup_id
      @block = b
      @readers = Set.new
      @mutex = Mutex.new
      @open = true
      @queue = []
    end

    def to_s
      "input-streamer##{@id}:#{@block.source_location.join(':')}"
    end

    def add_reader(*); end
    def add_writer(*); end
    def remove_reader(*); end
    def remove_writer(*); end

    def write(*); end

    def read
      @mutex.synchronize do
        call_out while @open && @queue.empty?

        next unless @open

        return @queue.shift
      end

      interrupt_process!(Proc.current)
    end

    def reset!
      @mutex.synchronize do
        @open = true
        @queue.clear
        @readers.clear
      end
    end

    def inspect_crit
      "#<#{self.class.name}>"
    end

  private
    def call_out
      input = @block.call or return (@open = false)
      @queue.concat(input)
    end

  end

  class Collector < Streamer
    attr_reader :collection

    def initialize
      setup_id
      @collection = []
      super { |val| @mutex.synchronize { @collection << val } }
    end

    def to_s
      "collector##{@id}:[#{@collection.size}]"
    end

    def inspect
      "#<Collector #{@collection.map(&:repr).join(' ')}>"
    end
  end
end
