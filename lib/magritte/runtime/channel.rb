module Magritte
  module Runtime
    class Blocker
      attr_reader :proc

      def inspect
        repr
      end
    end

    class Receiver < Blocker
      attr_reader :output
      def initialize(proc_, output)
        @proc = proc_
        @output = output
      end

      def <<(val)
        @output << val
        self
      end

      def repr
        "#receiver(#{@proc.pid})"
      end
    end

    class Sender < Blocker
      attr_reader :vals
      def initialize(proc_, vals)
        @proc = proc_
        @vals = vals
        @index = 0
      end

      def next_val
        out = @vals[@index]
        @index += 1
        out
      end

      def current_val
        @vals[@index]
      end

      def done?
        @index >= @vals.size
      end

      def send(receiver)
        receiver << vals.shift
        @proc.state = :running if @vals.empty?
      end

      def repr
        "#sender@#{@index}(#{@vals[@index..].map(&:repr).join(' ')})"
      end
    end

    class Channel
      attr_accessor :id
      def initialize(scheduler)
        @scheduler = scheduler

        @state = :init

        @reader_count = 0
        @writer_count = 0

        @senders = []
        @receivers = []
      end

      def open?; @state != :closed; end
      def closed?; @state == :closed; end

      def write_all(proc_, vals)
        proc_.interrupt!(self) if closed?

        @senders << Sender.new(proc_, vals)
      end

      def write(proc_, val)
        write_all(proc_, [val])
      end

      def read(proc_, out)
        return proc_.interrupt!(self) if closed?

        @receivers << Receiver.new(proc_, out)
      end

      def add_writer(p); @writer_count += 1; end
      def add_reader(p); @reader_count += 1; end
      def rm_writer(p); open? && @writer_count -= 1; end
      def rm_reader(p); open? && @reader_count -= 1; end

      def resolve!
        p :resolve! => [@senders, @receivers] if (@senders + @receivers).any?
        while @senders.size > 0 && @receivers.size > 0
          sender, receiver = @senders.shift, @receivers.shift

          receiver << sender.next_val

          receiver.proc.state = :running

          if sender.done?
            sender.proc.state = :running
          else
            @senders.unshift(sender)
          end
        end

        @senders.each { |s| p :wait => s; s.proc.state = :waiting }
        @receivers.each { |s| p :wait => s; s.proc.state = :waiting }

        check_for_close!
      end

      def check_for_close!
        p :check_for_close! => [@state, @reader_count, @writer_count]
        if @state == :init && @reader_count > 0 && @writer_count > 0
          @state = :open
          return
        end

        return false unless @state == :open
        return false unless @reader_count == 0 || @writer_count == 0

        @state = :closed

        true
      end

      def inspect
        repr
      end

      def repr
        "#channel@#{@id}:#{@reader_count}.#{@writer_count}.:#{@state}"
      end
    end

    class Collector < Channel
      def repr
        "#collector@#{@id}:#{@writer_count}.#{@state}"
      end

      attr_reader :output
      def initialize(scheduler, output)
        super(scheduler)
        @output = output
      end

      def check_for_close!
        case @state
        when :init
          @state = :open if @writer_count > 0
          false
        when :open
          @state = :closed if @writer_count - close_waiters.size == 0
          @state == :closed
        else
          false
        end
      end

      def close_waiters
        @close_waiters ||= []
      end

      def wait_for_close(proc_)
        puts "wait_for_close(#{self.repr})"
        close_waiters << proc_
      end

      def wakeup_close_waiters!
        close_waiters.each { |p| p.state = :running }
      end

      def resolve!
        while s = @senders.shift
          @state = :open

          s.vals.each do |v|
            @scheduler.log("##{@id} << #{v.repr}")
            @output << v
          end

          s.proc.state = :running
        end

        check_for_close! and wakeup_close_waiters!
      end
    end
  end
end
