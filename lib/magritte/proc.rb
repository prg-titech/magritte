module Magritte
  class Proc
    def self.current
      Thread.current[:magritte_proc] or raise 'no proc'
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
        rescue Exception => e
          PRINTER.p :exception
          PRINTER.p e
          raise
        ensure
          Proc.current.cleanup!
        end
      end

      p = Proc.new(t, env, in_ch, out_ch)

      # will be unlocked in Proc#start
      t[:magritte_start_mutex] = start_mutex

      # provides Proc.current
      t[:magritte_proc] = p
    end

    def inspect
      "#<Proc #{@thread.inspect}>"
    end

    def wait
      PRINTER.p waiting: self
      start
      @thread.join
    end

    attr_reader :thread, :in_ch, :out_ch
    def initialize(thread, env, in_ch, out_ch)
      @thread = thread
      @env = env
      @in_ch = in_ch
      @out_ch = out_ch
      @children = []
    end

    def start
      @thread[:magritte_start_mutex].unlock
      self
    end

    def alive?
      @thread.alive?
    end

    def interrupt!
      return unless alive?

      # will run cleanup in the thread via the ensure block
      @thread.kill
    end

    def cleanup!
      PRINTER.p :cleanup => self
      in_ch.each { |c| c.remove_reader(self) }
      out_ch.each { |c| c.remove_writer(self) }
    end

    def open_channels
      PRINTER.p 'opening in channels'
      in_ch.each { |c| c.add_reader(self) }

      PRINTER.p 'opening out channels'
      out_ch.each { |c| c.add_writer(self) }
    end

    def stdout
      out_ch.first || Channel::Null.new
    end

    def stdin
      in_ch.first || Channel::Null.new
    end
  end
end
