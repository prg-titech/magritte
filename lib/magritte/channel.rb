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

    def sleep
      log :sleep
      @mutex.sleep
      log :wake
    end
  end

  class Channel
    def initialize
      @readers = Set.new
      @writers = Set.new

      @mutex = LogMutex.new :only

      @block_type = :none
      @block_set = []

      @open = true
    end

    def open?
      @open
    end

    def closed?
      !@open
    end

    def add_reader(p)
      @mutex.synchronize { @readers << p }
    end

    def add_writer(p)
      @mutex.synchronize { @writers << p }
    end

    def remove_reader(p)
      @mutex.synchronize do
        @block_set.delete(p.thread) if @block_type == :read

        cleanup_from(p, @readers)
      end.call
    end

    def remove_writer(p)
      @mutex.synchronize do
        @block_set.delete(p.thread) if @block_type == :write

        cleanup_from(p, @writers)
      end.call
    end

    def read
      @mutex.synchronize do
        if closed?
          PRINTER.p("closed on read")
          next proc { Proc.current.interrupt! }
        end

        @block_set.shuffle!

        PRINTER.p(init_read: @block_type)
        out = case @block_type
        when :none
          @block_type = :read
          block_read
        when :read
          block_read
        when :write
          wakeup_read
        end
      end.call
    end

    def write(val)
      @mutex.synchronize do
        if closed?
          PRINTER.p("closed on write")
          next proc { Proc.current.interrupt! }
        end

        @block_set.shuffle!

        PRINTER.p(init_write: @block_type)
        case @block_type
        when :none
          @block_type = :write
          block_write(val)
        when :write
          block_write(val)
        when :read
          wakeup_write(val)
        end
      end.call
    end

    def inspect
      if @mutex.owned?
        inspect_crit
      else
        @mutex.synchronize { inspect_crit }
      end
    end

    private

    def cleanup_from(p, set)
      should_close = open? && (set.delete(p); set.empty?)

      if should_close
        @open = false
        to_clean = @block_set.dup
        @block_set.clear
        proc { to_clean.each { |t| t[:magritte_proc].interrupt! } }
      else
        proc { } # nop
      end
    end

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
      @mutex.sleep

      # action for after unlocking mutexes
      proc { }
    end

    def block_read
      @block_set << Thread.current
      @mutex.sleep

      # action for after unlocking mutexes
      proc { Thread.current[:__magritte_read] }
    end

    def wakeup_write(val)
      read_thread = @block_set.shift
      @block_type = :none if @block_set.empty?
      read_thread[:__magritte_read] = val

      raise 'read_thread still running!' unless read_thread.stop?

      read_thread.run

      # action for after unlocking mutexes
      proc do
        # nop
      end
    end

    def wakeup_read
      write_thread = @block_set.shift
      @block_type = :none if @block_set.empty?

      out = write_thread[:__magritte_write]
      raise 'write_thread still running!' unless write_thread.stop?

      write_thread.run

      proc { out }
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

