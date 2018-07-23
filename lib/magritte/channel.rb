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
      # PRINTER.p disp => a
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

    def owned?
      @mutex.owned?
    end
  end

  class Channel
    def initialize
      @readers = Set.new
      @writers = Set.new

      @readers_mutex = LogMutex.new :readers
      @writers_mutex = LogMutex.new :writers

      @comm_mutex = LogMutex.new :blocked
      @block_type = :none
      @block_set = []

      @read_count = 0
      @write_count = 0

      @open = true
    end

    def open?
      @open
    end

    def closed?
      !@open
    end

    def add_reader(p)
      @readers_mutex.synchronize do
        @readers << p
      end
    end

    def add_writer(p)
      @writers_mutex.synchronize do
        @writers << p
      end
    end

    def remove_reader(p)
      @readers_mutex.synchronize do
        @readers.delete(p)
        close! if @readers.empty?
      end
    end

    def remove_writer(p)
      @writers_mutex.synchronize do
        @writers.delete(p)
        close! if @writers.empty?
      end
    end

    def read
      @writers_mutex.synchronize do
        if closed?
          PRINTER.p("closed on read")
          Proc.current.interrupt!
        end

        @comm_mutex.synchronize do
          @block_set.shuffle!

          case @block_type
          when :none
            @block_type = :read
            block_read
          when :read
            block_read
          when :write
            wakeup_read
          end
        end
      end.call
    end

    def write(val)
      @readers_mutex.synchronize do
        if closed?
          PRINTER.p("closed on write")
          Proc.current.interrupt!
        end

        @comm_mutex.synchronize do
          @block_set.shuffle!

          case @block_type
          when :none
            @block_type = :write
            block_write(val)
          when :write
            block_write(val)
          when :read
            wakeup_write(val)
          end
        end
      end.call
    end

    def inspect
      if @comm_mutex.owned?
        inspect_crit
      else
        @comm_mutex.synchronize { inspect_crit }
      end
    end

    private

    def inspect_crit
      dots = '*' * @block_set.size
      s = case @block_type
      when :none
        '.'
      when :read
        ":#{dots}"
      when :write
        "#{dots}:"
      end

      o = @open ? 'o' : 'x'

      "#<Channel #{o} #{s}>"
    end

    def block_write(val)
      Thread.current[:__magritte_write] = val
      @block_set << Thread.current

      # action for after unlocking mutexes
      proc { Thread.stop }
    end

    def block_read
      @block_set << Thread.current

      # action for after unlocking mutexes
      proc { Thread.stop; Thread.current[:__magritte_read] }
    end

    def wakeup_write(val)
      read_thread = @block_set.shift
      @block_type = :none if @block_set.empty?
      read_thread[:__magritte_read] = val

      # action for after unlocking mutexes
      proc { read_thread.run }
    end

    def wakeup_read
      write_thread = @block_set.shift
      @block_type = :none if @block_set.empty?

      out = write_thread[:__magritte_write]
      proc { write_thread.run; out }
    end

    def close!
      PRINTER.p(close!: self)
      return unless @open
      @open = false

      @comm_mutex.synchronize do
        @block_set.each { |t| t[:magritte_proc].interrupt! }
      end
    end
  end

  class Collector < Channel
    attr_reader :collection
    def initialize
      @collection = []
      @mutex = Mutex.new
    end

    def add_writer(*); end
    def add_reader(*); end
    def remove_reader(*); end
    def remove_writer(*); end

    def read
      raise 'not readable'
    end

    def write(val)
      @mutex.synchronize { @collection << val }
    end

    def close!
      # pass
    end

    def inspect
      "#<Collector #{@collection.inspect}>"
    end
  end

  class Null < Channel
    def initialize
      @open = true
    end

    def add_writer(*); end
    def add_reader(*); end
    def remove_reader(*); end
    def remove_writer(*); end

    def inspect
      "#<Null>"
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

