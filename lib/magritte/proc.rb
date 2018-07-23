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

    def self.spawn(code, env, in_ch, out_ch)
      start_mutex = Mutex.new
      start_mutex.lock

      t = Thread.new do
        begin
          # wait for Proc#start
          start_mutex.lock

          # Proc.current should be available now
          Proc.current.open_channels

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
        end
      end

      p = Proc.new(t, code, env, in_ch, out_ch)

      # will be unlocked in Proc#start
      t[:magritte_start_mutex] = start_mutex

      # provides Proc.current
      t[:magritte_proc] = p
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

    attr_reader :thread, :in_ch, :out_ch
    def initialize(thread, code, env, in_ch, out_ch)
      @alive = false
      @thread = thread
      @code = code
      @env = env
      @in_ch = in_ch
      @out_ch = out_ch
      @children = []
      @call_depth = 0
    end

    def start
      @alive = true
      @thread[:magritte_start_mutex].unlock
      self
    end

    def alive?
      @alive && @thread.alive?
    end

    def interrupt!
      return unless alive?

      # will run cleanup in the thread via the ensure block
      @thread.raise(Interrupt.new)
    end

    def sleep
      @thread.stop
    end

    def wakeup
      @thread.run
    end

    def cleanup!
      PRINTER.p :cleanup => self
      in_ch.each { |c| c.remove_reader(self) }
      out_ch.each { |c| c.remove_writer(self) }
    end

    def open_channels
      in_ch.each { |c| c.add_reader(self) }
      out_ch.each { |c| c.add_writer(self) }
    end

    def stdout
      out_ch.first || Channel::Null.new
    end

    def stdin
      in_ch.first || Channel::Null.new
    end

  protected
    def with_channels(new_in, new_out, &b)
      old_in, @in_ch = in_ch, new_in
      old_out, @out_ch = out_ch, new_out
      yield
    rescue Interrupt
      PRINTER.puts('virtual proc interrupted')
      # pass
    ensure
      (@in_ch - old_in).each { |c| c.remove_reader(self) }
      (@out_ch - old_out).each { |c| c.remove_writer(self) }

      old_in && @in_ch = old_in
      old_out && @out_ch = old_out
    end
  end
end
