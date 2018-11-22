module Magritte

  class Streamer < Channel
    def initialize(&b)
      @output = b
      @mutex = Mutex.new
      @writers = Set.new
      @close_waiters = []
      @open = true
    end

    def add_reader(*); end
    def remove_reader(*); end

    def remove_writer(p)
      action = @mutex.synchronize do
        next :nop unless @open
        @writers.delete(p)

        next :nop unless @writers.empty?

        @open = false
        :close
      end

      @close_waiters.each { |t| t.run } if action == :close
    end

    def read
      raise 'not readable'
    end

    def write(val)
      @output.call(val)
    end

    def wait_for_close
      @mutex.synchronize do
        next unless @open
        @close_waiters << Thread.current
        @mutex.sleep
      end
    end

    def reset!
      @mutex.synchronize do
        @open = true
        @close_waiters.clear
        @writers.clear
      end
    end

    def inspect_crit
      "#<#{self.class.name}>"
    end
  end

  class InputStreamer < Channel
    def initialize(&b)
      @block = b
      @readers = Set.new
      @mutex = Mutex.new
      @open = true
      @queue = []
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

      Proc.current.interrupt!
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
      @collection = []
      super { |val| @mutex.synchronize { @collection << val } }
    end

    def inspect
      "#<Collector #{@collection.inspect}>"
    end
  end
end
