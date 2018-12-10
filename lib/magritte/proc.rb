module Magritte
  class Proc
    class Interrupt < RuntimeError
      attr_reader :status

      def initialize(status)
        @status = status
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
            Proc.current.compensate(e)
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
      @thread.join

      if Proc.current?
        Proc.current.interrupt!(@thread[:status]) if @thread[:status].property?(:crash)
      end

      @thread[:status]
    end

    def join
      alive? && @thread.join
    end

    attr_reader :thread
    def initialize(thread, code, env)
      @alive = false
      @thread = thread
      @code = code
      @env = env
      @stack = []

      @interrupt_mutex = LogMutex.new :interrupt
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
      @interrupt_mutex.synchronize do
        return unless alive?

        # will run cleanup in the thread via the ensure block
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

  protected
    def enter_frame(*args, &b)
      stack_size = @stack.size

      @interrupt_mutex.synchronize do
        frame = Frame.new(self, *args)
        PRINTER.p :stack => @stack
        @stack << frame
      end

      frame.open_channels

      out = yield
    rescue Interrupt => e
      compensate(e)
      PRINTER.p :interrupt => @stack
      raise
    else
      binding.pry if stack_size+1 != @stack.size
      checkpoint
      PRINTER.p :checkpoint => @stack
      out
    end
  end
end
