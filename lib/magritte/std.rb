module Magritte
  module Std
    extend self
    def put(val)
      Proc.current.stdout.write(val)
    end

    def get
      out = Proc.current.stdin.read
      # PRINTER.p get: [out, stdin]
      out
    end

    def call(h, a, range=nil)
      range ||= Proc.current.trace.last.range
      h.call(a, range)
    end

    def loop_channel(c, &b)
      loop { b.call }
    rescue Proc::Interrupt => e
      reason = e.status.reason
      raise unless reason && reason.is_a?(Reason::Close) && reason.channel == c
    end

    def produce(&b)
      loop_channel(Proc.current.stdout, &b)
    end

    def consume(&b)
      loop_channel(Proc.current.stdin, &b)
    end

    def bool(b)
      b ? Status.normal : Status[:fail]
    end

    def make_channel
      Channel.new
    end

    def for_(iterable)
      iterable.each { |val| put(val) }
    end

    def each
      consume { yield get }
    end

    def map
      consume { put (yield get) }
    end

    def take(n)
      n.times { put(get) }
    end

    def spawn_proc(&b)
      i = make_channel
      o = make_channel
      s(&b).into(o).from(i).go

      [i, o]
    end

    def drain
      loop { put(get) }
    end

    def server(&b)
      i, o = spawn_proc(&b)
      s { drain }.into(Null.new).from(o).go
      s { Thread.stop }.into(i).go

      i
    end

    def server_request(channel, message)
      receiver = make_channel
      s { put [message, receiver] }.into(channel).call
      s { put get }.from(receiver).collect.first
    end

    def server_send(channel, message)
      s { put [message, nil] }.into(channel).call
      nil
    end

    def make_ref(init_val)
      server {
        val = init_val
        loop {
          message, receiver = get
          tag, arg = message

          p :received => [tag, arg, receiver]

          case tag
          when :set then val = arg
          when :get then s { put val }.into(receiver).call
          when :die then break
          else raise "bad message #{message.inspect}"
          end
        }
      }
    end
  end
end
