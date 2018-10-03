module Magritte
  class Proc
    class Interrupt < Exception
    end

    def self.current
      Thread.current[:magritte_proc] or raise 'no proc'
    end

    def self.with_channels(in_ch, out_ch, &b)
      current.send(:with_channels, in_ch, out_ch, &b)
    end

    def self.spawn(code, env)
      start_mutex = Mutex.new
      start_mutex.lock

      t = Thread.new do
        begin
          # wait for Proc#start
          start_mutex.lock

          code.run
        rescue Interrupt
          PRINTER.puts('real proc interrupted')
          # pass
        rescue Exception => e
          PRINTER.p :exception
          PRINTER.p e
          PRINTER.puts e.backtrace
          raise
        ensure
          @alive = false
          Proc.current.cleanup!
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
    end

    def join
      alive? && @thread.join
    end

    attr_reader :thread, :env
    def initialize(thread, code, env)
      @alive = false
      @thread = thread
      @code = code
      @env = env

      @interrupt_mutex = LogMutex.new :interrupt
    end

    def start
      @alive = true
      open_channels
      @thread[:magritte_start_mutex].unlock
      self
    end

    def alive?
      @alive && @thread.alive?
    end

    def interrupt!
      @interrupt_mutex.synchronize do
        return unless alive?

        # will run cleanup in the thread via the ensure block
        @thread.raise(Interrupt.new)
      end
    end

    def sleep
      @thread.stop
    end

    def wakeup
      @thread.run
    end

    def cleanup!
      PRINTER.p :cleanup => self
      @env.each_input { |c| c.remove_reader(self) }
      @env.each_output { |c| c.remove_writer(self) }
    end

    def open_channels
      @env.each_input { |c| c.add_reader(self) }
      @env.each_output { |c| c.add_writer(self) }
    end

    def stdout
      @env.stdout || Channel::Null.new
    end

    def stdin
      @env.stdin || Channel::Null.new
    end

  protected
    def with_channels(new_in, new_out, &b)
      old_env = nil
      new_env = nil

      @interrupt_mutex.synchronize do
        old_env = @env
        new_env = @env = @env.extend(new_in, new_out)
      end

      yield
    rescue Interrupt
      PRINTER.puts('virtual proc interrupted')
      # pass
    ensure
      @interrupt_mutex.synchronize do
        @env = old_env
      end

      new_env.own_inputs.each { |c| c.remove_reader(self) }
      new_env.own_outputs.each { |c| c.remove_writer(self) }
    end
  end
end
