module Magritte
  module Std
    def put(val)
      PRINTER.p put: [val, stdout]
      Proc.current.stdout.write(val)
    end

    def get
      out = Proc.current.stdin.read
      # PRINTER.p get: [out, stdin]
      out
    end

    def make_channel
      Channel.new
    end

    def for_(iterable)
      iterable.each { |val| put(val) }
    end

    def each
      loop do
        yield get
      end
    end

    def map
      loop do
        put (yield get)
      end
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
