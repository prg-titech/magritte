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

    def self.check_interrupt!
      current.check_interrupt!
    end

    def self.spawn(code, env)
      start_mutex = Mutex.new
      start_mutex.lock

      t = Thread.new do
        begin
          # wait for Proc#start
          start_mutex.lock
          Thread.current[:status] = Status[:incomplete]
          Thread.current[:status] = begin
            code.run
          rescue Interrupt => e
            PRINTER.p("root compensation #{Proc.current.inspect}")
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
          PRINTER.puts("shutting down, final ensure #{Proc.current.inspect}")
          @alive = false
          Proc.current.checkpoint_all
          PRINTER.puts("exiting #{Proc.current.inspect}")
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
      "#<Proc #{@code.loc} #{@interrupts.inspect} [#{@stack.map(&:inspect).join(' ')}]>"
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
      @interrupts = []

      @mutex = LogMutex.new "interrupt_#{LogPrinter.thread_name(@thread)}"
    end

    def env
      frame.env
    end

    def frame
      binding.pry if @stack.empty?
      @stack.last
    end

    def own_thread!
      raise Exception.new('cannot call on different thread') unless @thread == Thread.current
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
      @mutex.synchronize do
        next unless alive?

        @interrupts << Interrupt.new(status)
        @thread.run
      end
    end

    def check_interrupt!
      own_thread!

      ex = @mutex.synchronize do
        PRINTER.puts("check_interrupt! #{@interrupts.inspect}")
        @mutex.log("check_interrupt! #{@interrupts.inspect}")
        @interrupts.shift
      end

      raise ex if ex
    end

    def crash!(msg=nil)
      own_thread!

      interrupt!(Status[:crash, reason: Reason::Crash.new(msg)])
      check_interrupt!
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
      own_thread!

      frame.add_compensation(comp)
    end

    def compensate(status)
      own_thread!
      # if the stack is empty there is nothing to do

      PRINTER.p("compensate popping #{@stack.size}")

      frame = @stack.pop
      frame && frame.compensate(status)
      check_interrupt!
    end

    def checkpoint
      own_thread!

      PRINTER.p("checkpoint popping #{@stack.size}")
      frame = @stack.last
      frame && frame.checkpoint
      @stack.pop
      check_interrupt!
    end

    def compensate_all(e)
      own_thread!

      (compensate(e) rescue Interrupt) until @stack.empty?
    end

    def checkpoint_all
      own_thread!

      (checkpoint rescue Interrupt) until @stack.empty?
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
      own_thread!

      PRINTER.p("trace: #{callable.name} #{range}")
      @trace << Tracepoint.new(callable, range)
      yield
    ensure
      @trace.pop
    end

    attr_reader :trace

  protected
    def re_raise?(e)
      reason = e.status.reason
      return true unless reason.is_a?(Reason::Close)

      test = proc { |c| return true if c == reason.channel }

      case reason.direction
      when :< then env.each_input(&test)
      when :> then env.each_output(&test)
      end

      false
    end

    def enter_frame(*args, &b)
      own_thread!

      stack_size = @stack.size

      frame = Frame.new(self, *args)
      frame.open_channels

      if @stack.last.tail?
        PRINTER.p("tail-popping #{@stack.size} #{@stack.last.inspect}")
        tail = @stack.pop
        tail.unregister_channels
        frame.compensations.concat(tail.compensations)
        tail.elim!
      end

      PRINTER.p :stack => @stack
      @stack << frame


      PRINTER.p 'channels opened'

      out = yield
    rescue Interrupt => e
      compensate(e) unless frame.elim?
      PRINTER.p :interrupt => [e.status, @stack]
      if re_raise?(e)
        raise
      else
        e.status
      end
    else
      unless frame.elim?
        checkpoint
        PRINTER.p :checkpoint => @stack
      end

      out
    end
  end
end
