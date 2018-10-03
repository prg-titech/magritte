module Magritte
  class Blocker
    attr_reader :thread, :val

    def interrupt!
      @thread[:magritte_proc].interrupt!
    end

    def wakeup
      raise "#{self.inspect} still running!" unless @thread.stop?

      @thread.run
    end
  end

  class Sender < Blocker
    def initialize(thread, val)
      @thread, @val = thread, val
    end
  end

  class Receiver < Blocker
    def initialize(thread)
      @thread = thread
    end

    def <<(val)
      @val = val
    end
  end

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
    IDS_MUTEX = Mutex.new
    @@max_id = 0

    def initialize
      @readers = Set.new
      @writers = Set.new

      @mutex = Mutex.new
      @id = IDS_MUTEX.synchronize { @@max_id += 1 }

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
        unregister_thread(p.thread) if @block_type == :read

        cleanup_from(p, @readers)
      end.call
    end

    def remove_writer(p)
      @mutex.synchronize do
        unregister_thread(p.thread) if @block_type == :write

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
      # doesn't entirely get rid of race conditions because
      # @block_set may still be mutated, but makes it less
      # likely i think?
      dup.inspect_crit
    end

    protected

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

      "#<Channel##{@id} #{o} #{s}>"
    end

    private

    def unregister_thread(t)
      @block_set.reject! { |b| b.thread == t }
    end

    def cleanup_from(p, set)
      should_close = open? && (set.delete(p); set.empty?)

      if should_close
        @open = false
        to_clean = @block_set.dup
        @block_set.clear
        proc { to_clean.each(&:interrupt!) }
      else
        proc { } # nop
      end
    end

    def block_write(val)
      @block_set << Sender.new(Thread.current, val)
      @mutex.sleep

      # action for after unlocking mutexes
      proc { }
    end

    def block_read
      receiver = Receiver.new(Thread.current)
      @block_set << receiver
      @mutex.sleep

      # action for after unlocking mutexes
      proc { receiver.val }
    end

    def wakeup_write(val)
      receiver = @block_set.shift
      @block_type = :none if @block_set.empty?
      receiver << val

      receiver.wakeup

      # action for after unlocking mutexes
      proc do
        # nop
      end
    end

    def wakeup_read
      sender = @block_set.shift
      @block_type = :none if @block_set.empty?
      sender.wakeup

      proc { sender.val }
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
  private

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

