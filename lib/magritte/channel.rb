$DEBUG_MUTEX = Mutex.new

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
      if PRINTER.is_a?(LogPrinter)
        File.open("tmp/log/#{$$}/#{disp}", 'a') { |f| f.puts *a }
      end
    end

    def p(*a)
      log(*a.map(&:inspect))
    end

    def synchronize(&b)
      trace = caller[0]

      out = nil
      @mutex.synchronize do
        begin
          log "lock  : #{trace}"
          out = yield
        ensure
          log "unlock: #{trace}"
        end
      end
      out
    end

    def owned?
      @mutex.owned?
    end

    def sleep
      log "sleep : #{caller[0]}"
      @mutex.sleep
      log :wake
    end
  end

  class Channel
    IDS_MUTEX = Mutex.new
    @@max_id = 0

    def initialize
      @id = IDS_MUTEX.synchronize { @@max_id += 1 }
      @mutex = LogMutex.new("channel_#{@id}")
      setup
    end

    def setup
      @readers = Set.new
      @writers = Set.new
      @block_type = :none
      @block_set = []

      @open = true
    end

    def reset!
      @mutex.synchronize { @open = false }
      interrupt_blocked!
      @mutex.synchronize { setup }
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
        @mutex.p([@block_type, @block_set.size])
        next :nop unless @readers.empty?

        @mutex.p("CLOSE")

        @open = false
        :close
      end

      if action == :close
        PRINTER.p(close: [@id, @block_type, @block_set])
      end

      interrupt_blocked! if action == :close
    rescue ThreadError
      binding.pry
    end

    def remove_writer(p)
      action = @mutex.synchronize do
        next :nop unless open?
        @block_set.reject! { |b| b.thread == p.thread } if @block_type == :write


        @writers.delete(p)
        next :nop unless @writers.empty?

        @mutex.log "CLOSE"
        @open = false
        :close
      end

      PRINTER.p(closing_channel: @id) if action == :close
      interrupt_blocked! if action == :close
    end

    def interrupt_blocked!
      @block_set.each { |b| interrupt_process!(b) }
    end

    def read
      @mutex.synchronize do
        unless @open
          PRINTER.p("closed on read")
          @mutex.p("interrupting #{LogPrinter.thread_name(Thread.current)}")

          # jump to the end of the block
          next
        end

        @block_set.shuffle!

        @mutex.p(read: [@id, @block_type, open: @open])
        PRINTER.p(read: [@id, @block_type, open: @open])
        out = case @block_type
        when :none, :read
          @block_type = :read

          receiver = Receiver.new(Thread.current)
          @block_set << receiver
          Proc.interruptable { @mutex.sleep; return receiver.val }
        when :write
          sender = @block_set.shift
          @block_type = :none if @block_set.empty?

          sender.wakeup
          Proc.interruptable { return sender.val }
        end
      end

      interrupt_process!(Proc.current)
    end

    def write(val)
      @mutex.synchronize do
        unless @open
          PRINTER.p("closed on write")
          @mutex.p("interrupting #{LogPrinter.thread_name(Thread.current)}")
          next
        end

        @block_set.shuffle!

        @mutex.p(write: [@id, @block_type])
        PRINTER.p(write: [@id, @block_type])
        case @block_type
        when :none, :write
          @block_type = :write
          @block_set << Sender.new(Thread.current, val)
          Proc.interruptable { @mutex.sleep }
          return
        when :read
          receiver = @block_set.shift or PRINTER.p(EMPTY_BLOCK_SET: [@block_type, self])
          @block_type = :none if @block_set.empty?

          receiver.set(val)
          receiver.wakeup
          Proc.interruptable { }
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

