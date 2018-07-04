module Magritte
  class LogMutex
    def initialize(name)
      @name = name
      @mutex = Mutex.new
    end

    def disp
      :"mut_#{@name}"
    end

    def log(*a)
      PRINTER.p disp => a
    end

    def synchronize(&b)
      out = nil
      log :lock
      @mutex.synchronize do
        log :locked
        out = yield
        log :unlock
      end
      log :unlocked
      out
    end

    def spawn_sync(&b)
      Thread.new do
        synchronize(&b)
      end
    end
  end

  class Channel
    def initialize
      @readers = Set.new
      @writers = Set.new

      @read_mutex = LogMutex.new :read
      @write_mutex = LogMutex.new :write

      @readers_mutex = LogMutex.new :readers
      @writers_mutex = LogMutex.new :writers

      @read_count = 0
      @write_count = 0

      @channel = Concurrent::Channel.new
      @open = true
    end

    def open?
      @open
    end

    def closed?
      !@open
    end

    def add_reader(p)
      PRINTER.p "trying to synchronize add_reader"
      @readers_mutex.synchronize do
        PRINTER.p(add_reader: object_id)
        @readers << p
      end
    end

    def add_writer(p)
      PRINTER.p "trying to synchronize add_writer"
      @writers_mutex.synchronize do
        PRINTER.p(add_writer: object_id)
        @writers << p
      end
    end

    def remove_reader(p)
      @readers_mutex.synchronize do
        PRINTER.p(remove_reader: object_id)
        @readers.delete(p)
        close! if @readers.empty?
      end
    end

    def remove_writer(p)
      @writers_mutex.synchronize do
        PRINTER.p(remove_writer: object_id)
        @writers.delete(p)
        close! if @writers.empty?
      end
    end

    def read
      @writers_mutex.synchronize do
        @read_count += 1
        PRINTER.p(read: @read_count)

        p = Proc.current

        if closed?
          PRINTER.p("closed")
          p.interrupt!
        end

        Thread.new { @channel.take }
      end.value
    end

    def write(val)
      @readers_mutex.synchronize do
        @write_count += 1
        PRINTER.p(write: @write_count)

        p = Proc.current

        if closed?
          PRINTER.p("closed")
          p.interrupt!
        end

        Thread.new { @channel << val }
      end.join
    end

    def close!
      PRINTER.p(close!: object_id)
      @open = false

      # @readers.each(&:interrupt!)
      # @writers.each(&:interrupt!)
    end
  end

  class Collector < Channel
    attr_reader :collection
    def initialize
      @collection = []
    end

    def add_writer(*); end
    def add_reader(*); end
    def remove_reader(*); end
    def remove_writer(*); end

    def read
      raise 'not readable'
    end

    def write(val)
      @collection << val
    end

    def close!
      # pass
    end
  end

  class Null < Channel
    def initialize
      @open = true
    end

    def read
      # block forever
      Thread.stop

      # should not happen
      raise 'woken up after reading from null'
    end

    def write(val)
      # pass
    end
  end
end

