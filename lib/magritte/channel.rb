module Magritte
  class Blocker
    attr_reader :thread, :val

    def interrupt!(status)
      @thread[:magritte_proc].interrupt!(status)
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

    def set(val)
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
      action = @mutex.synchronize do
        next :nop unless @open
        @block_set.reject! { |b| b.thread == p.thread } if @block_type == :read

        @readers.delete(p)
        next :nop unless @readers.empty?

        @open = false
        :close
      end

      PRINTER.p(closing_channel: @id) if action == :close
      @block_set.each { |b| interrupt_process!(b) } if action == :close
    end

    def remove_writer(p)
      action = @mutex.synchronize do
        next :nop unless open?
        @block_set.reject! { |b| b.thread == p.thread } if @block_type == :write


        @writers.delete(p)
        next :nop unless @writers.empty?

        @open = false
        :close
      end

      PRINTER.p(closing_channel: @id) if action == :close
      @block_set.each { |b| interrupt_process!(b) } if action == :close
    end

    def read
      @mutex.synchronize do
        if closed?
          PRINTER.p("closed on read")

          # jump to the end of the block
          next
        end

        @block_set.shuffle!

        PRINTER.p(init_read: @block_type)
        out = case @block_type
        when :none, :read
          @block_type = :read

          receiver = Receiver.new(Thread.current)
          @block_set << receiver
          @mutex.sleep

          return receiver.val
        when :write
          sender = @block_set.shift
          @block_type = :none if @block_set.empty?

          sender.wakeup
          return sender.val
        end
      end

      interrupt_process!(Proc.current)
    end

    def write(val)
      @mutex.synchronize do
        if closed?
          PRINTER.p("closed on write")
          next
        end

        @block_set.shuffle!

        PRINTER.p(init_write: @block_type)
        case @block_type
        when :none, :write
          @block_type = :write
          @block_set << Sender.new(Thread.current, val)
          @mutex.sleep
          return
        when :read
          receiver = @block_set.shift
          @block_type = :none if @block_set.empty?

          receiver.set(val)
          receiver.wakeup
          return
        end
      end

      interrupt_process!(Proc.current)
    end

    def inspect
      # doesn't entirely get rid of race conditions because
      # @block_set may still be mutated, but makes it less
      # likely i think?
      dup.inspect_crit
    end

    protected

    def interrupt_process!(process)
      process.interrupt!(Status[reason: Reason::Close.new(self)])
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

      "#<Channel##{@id} #{o} #{s}>"
    end

    private

    def unregister_thread(t)
      @block_set.reject! { |b| b.thread == t }
    end

    def cleanup_from(p, set)
      return [] unless open?

      set.delete(p)

      if set.empty?
        @open = false
        to_clean = @block_set.dup
        @block_set.clear
        to_clean
      else
        []
      end
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

