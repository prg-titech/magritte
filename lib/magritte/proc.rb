module Magritte
  class Proc
    class Interrupt < RuntimeError
      attr_reader :status

      def initialize(status)
        @status = status
      end

      def to_s
        "!interrupt[#{@status.repr}]"
      end

      def inspect
        "#<#{self.class.name} #{@status.repr}>"
      end
    end

    def self.current
      Thread.current[:magritte_proc] or raise 'no proc'
    end

    def self.current?
      !!Thread.current[:magritte_proc]
    end

    def self.with_channels(in_ch, out_ch, &b)
      current.send(:with_channels, in_ch, out_ch, &b)
    end

    def self.enter_frame(*args, &b)
      current.send(:enter_frame, *args, &b)
    end

    def self.interruptable
      Thread.handle_interrupt(Interrupt => :immediate) { yield }
    end

    def self.spawn(code, env)
      start_mutex = Mutex.new
      start_mutex.lock

      t = Thread.new do
        Thread.handle_interrupt(Interrupt => :never) do
          begin
            # wait for Proc#start
            start_mutex.lock
            Thread.current[:status] = Status[:incomplete]
            Thread.current[:status] = begin
              code.run
            rescue Interrupt => e
              Proc.current.compensate(e)
              e.status
            end
          rescue Exception => e
            PRINTER.p :exception
            PRINTER.p e
            PRINTER.puts e.backtrace
            status = Status[:crash, :bug, reason: Reason::Bug.new(e)]
            Proc.current.compensate_all(status)
            Thread.current[:status] = status
            raise
          ensure
            @alive = false
            Proc.current.checkpoint_all
            PRINTER.puts('exiting')
          end
        end
      end

      p = Proc.new(t, code, env)

      # will be unlocked in Proc#start
      t[:magritte_start_mutex] = start_mutex

      # provides Proc.current
      t[:magritte_proc] = p

      p
    end

    def inspect
      "#<Proc #{@code.loc}>"
    end

    def wait
      PRINTER.p waiting: self
      start
      join
      @thread[:status]
    end

    def join
      @thread.join

      if Proc.current?
        Proc.current.interrupt!(@thread[:status]) if @thread[:status].property?(:crash)
      end

      alive? && @thread.join
    end

    attr_reader :thread
    def initialize(thread, code, env)
      @trace = []
      @alive = false
      @thread = thread
      @code = code
      @env = env
      @stack = []

      # @interrupt_mutex = LogMutex.new "interrupt_#{LogPrinter.thread_name(@thread)}"
    end

    def env
      frame.env
    end

    def frame
      @stack.last
    end

    def start
      @alive = true
      @stack << Frame.new(self, @env)
      frame.open_channels
      @thread[:magritte_start_mutex].unlock
      self
    end

    def alive?
      @alive && @thread.alive?
    end

    def interrupt!(status)
      return unless alive?

      if @thread == Thread.current
        raise Interrupt.new(status)
      else
        @thread.raise(Interrupt.new(status))
      end
    end

    def crash!(msg=nil)
      interrupt!(Status[:crash, reason: Reason::Crash.new(msg)])
    end

    def sleep
      @thread.stop
    end

    def wakeup
      @thread.run
    end

    def stdout
      env.stdout || Channel::Null.new
    end

    def stdin
      env.stdin || Channel::Null.new
    end

    def add_compensation(comp)
      frame.add_compensation(comp)
    end

    def compensate(status)
      frame = @stack.pop
      frame.compensate(status)
    end

    def checkpoint
      frame = @stack.pop
      frame.checkpoint
    end

    def compensate_all(e)
      compensate(e) until @stack.empty?
    end

    def checkpoint_all
      checkpoint until @stack.empty?
    end

    class Tracepoint
      attr_reader :callable
      attr_reader :range

      def initialize(callable, range)
        @callable = callable
        @range = range
      end
    end

    def with_trace(callable, range, &b)
      PRINTER.p("trace: #{callable.name} #{range}")
      @trace << Tracepoint.new(callable, range)
      yield
    ensure
      @trace.pop
    end

    attr_reader :trace

  protected
    def enter_frame(*args, &b)
      stack_size = @stack.size

      frame = Frame.new(self, *args)
      PRINTER.p :stack => @stack
      @stack << frame

      frame.open_channels

      out = yield
    rescue Interrupt => e
      compensate(e)
      PRINTER.p :interrupt => @stack
      raise
    else
      checkpoint
      PRINTER.p :checkpoint => @stack
      out
    end
  end
end
