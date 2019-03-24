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
      else
        PRINTER.puts(*a)
      end
    end

    def p(*a)
      log(disp, *a.map(&:inspect))
    end

    def synchronize(&b)
      trace = caller[0]

      out = nil
      @mutex.synchronize do
        begin
          # log "#{disp} lock  : #{trace}"
          out = yield
        ensure
          # log "#{disp} unlock: #{trace}"
        end
      end
      out
    end

    def owned?
      @mutex.owned?
    end

    def sleep
      log "#{disp} sleep : #{caller[0]}"
      @mutex.sleep
      log "#{disp} wake"
    end
  end

  ALL_CHANNELS = []
  class Channel
    IDS_MUTEX = Mutex.new
    @@max_id = 0

    def initialize
      setup_id
      setup
    end

    def setup_id
      IDS_MUTEX.synchronize do
        @id = @@max_id += 1
        @mutex = LogMutex.new("#{self.class.name.downcase}_#{@id}")
        ALL_CHANNELS << self
      end
    end

    def setup
      @readers = Set.new
      @writers = Set.new
      @block_type = :none
      @block_set = []

      @open = true
    end

    def reset!
      # @mutex.synchronize { @open = false }
      # interrupt_blocked!
      # @mutex.synchronize { setup }
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
        @mutex.log "[#{@id}] remove_reader #{@readers.size} #{p.inspect}"

        next :nop unless @open
        @block_set.reject! { |b| b.thread == p.thread } if @block_type == :read

        @readers.delete(p)
        @mutex.p([@block_type, @block_set.size])
        next :nop unless @readers.empty?

        @mutex.log "[#{@id}] CLOSE: #{@block_set.map(&:inspect).join(' ')}"

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
        @mutex.log "[#{@id}] remove_writer #{@writers.size} #{p.inspect}"
        @block_set.reject! { |b| b.thread == p.thread } if @block_type == :write


        @writers.delete(p)
        next :nop unless @writers.empty?

        @mutex.log "[#{@id}] CLOSE: #{@block_set.map(&:inspect).join(' ')}"
        @open = false
        :close
      end

      PRINTER.p(closing_channel: @id) if action == :close
      interrupt_blocked! if action == :close
    end

    def interrupt_blocked!
      interrupt_self = false
      @block_set.each do |b|
        if b.thread == Thread.current
          interrupt_self = true
        else
          interrupt_process!(b)
        end
      end

      interrupt_process!(Proc.current) if interrupt_self
    end

    def read
      result = @mutex.synchronize do
        unless @open
          PRINTER.p("#{@id} read: already closed")
          @mutex.p("interrupting #{LogPrinter.thread_name(Thread.current)}")

          interrupt_process!(Proc.current)

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
          @mutex.sleep
          @block_set.delete(receiver)
          receiver
        when :write
          sender = @block_set.shift
          @block_type = :none if @block_set.empty?

          sender.wakeup
          sender
        end
      end

      Proc.check_interrupt!

      result.val
    end

    def write(val)
      @mutex.synchronize do
        unless @open
          PRINTER.p("#{@id} write: already closed")
          @mutex.p("interrupting #{LogPrinter.thread_name(Thread.current)}")
          interrupt_process!(Proc.current)
          next
        end

        @block_set.shuffle!

        @mutex.p(write: [@id, @block_type])
        PRINTER.p(write: [@id, @block_type])
        case @block_type
        when :none, :write
          @block_type = :write
          sender = Sender.new(Thread.current, val)
          @block_set << sender
          @mutex.sleep
          @block_set.delete(sender)
        when :read
          receiver = @block_set.shift #  or PRINTER.p(EMPTY_BLOCK_SET: [@block_type, self])
          @block_type = :none if @block_set.empty?

          receiver.set(val)
          receiver.wakeup
        end
      end

      Proc.check_interrupt!
    end

    def inspect
      inspect_crit
      # doesn't entirely get rid of race conditions because
      # @block_set may still be mutated, but makes it less
      # likely i think?
      # dup.inspect_crit
    end

    def repr
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

      "[#{@id} #{o} #{s}]"
    end

    def to_s
      repr
    end

    protected

    def interrupt_process!(process)
      process.interrupt!(Status[reason: Reason::Close.new(self)])
    end

    def inspect_crit
      "#<#{self.class.name}#[#{repr}]>"
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

